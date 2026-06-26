import { Request, Response } from "express";
import ApiResponse from "../utils/response.util";
import prisma from "../config/prisma";

/**
 * Generate and Fetch the Daily Report.
 * 
 * Aggregates database Floats and Google API data (unread emails, calendar events, tasks)
 * for today, then calls Groq API (openai/gpt-oss-120b) to get a structured JSON summary.
 * 
 * @param req express request object
 * @param res express response object
 */
const getDailyReport = async (req: Request, res: Response) => {
    const userId = req.params.userId as string;
    const timeMin = req.query.timeMin as string;
    const timeMax = req.query.timeMax as string;

    if (!userId) {
        return ApiResponse(res, 400, "User ID is required");
    }

    if (!timeMin || !timeMax) {
        return ApiResponse(res, 400, "timeMin and timeMax query parameters are required");
    }

    try {
        // 1. Get user details from the database
        const user = await prisma.user.findUnique({
            where: { id: userId },
        });

        if (!user) {
            return ApiResponse(res, 404, "User not found");
        }

        // 2. Resolve a valid, non-expired Google Access Token
        let accessToken = user.accessToken;
        const now = new Date();

        if (!user.tokenExpiry || user.tokenExpiry <= now) {
            if (!user.refreshToken) {
                return ApiResponse(res, 401, "Google refresh token is missing. Please sign in again.");
            }

            const clientId = process.env.GOOGLE_CLIENT_ID || "";
            const clientSecret = process.env.GOOGLE_CLIENT_SECRET || "";

            if (!clientId || !clientSecret) {
                console.error("Missing GOOGLE_CLIENT_ID or GOOGLE_CLIENT_SECRET in .env");
                return ApiResponse(res, 500, "Server OAuth configuration error");
            }

            console.log(`Refreshing Google access token for user ${user.email}...`);

            const tokenResponse = await fetch("https://oauth2.googleapis.com/token", {
                method: "POST",
                headers: {
                    "Content-Type": "application/x-www-form-urlencoded",
                },
                body: new URLSearchParams({
                    client_id: clientId,
                    client_secret: clientSecret,
                    refresh_token: user.refreshToken,
                    grant_type: "refresh_token",
                }),
            });

            const tokenData = await tokenResponse.json();

            if (!tokenResponse.ok) {
                console.error("Failed to refresh Google token:", tokenData);
                return ApiResponse(res, 401, "Failed to refresh Google token. Please sign in again.");
            }

            accessToken = tokenData.access_token;
            const expires_in = tokenData.expires_in;
            const tokenExpiry = expires_in ? new Date(Date.now() + expires_in * 1000) : new Date(Date.now() + 3600 * 1000);

            await prisma.user.update({
                where: { id: userId },
                data: {
                    accessToken,
                    tokenExpiry,
                },
            });

            console.log(`Google access token refreshed successfully for user ${user.email}.`);
        }

        // 3. Fetch user's active Floats from DB
        const floats = await prisma.floatItem.findMany({
            where: {
                userId,
                isActive: true,
            },
            select: {
                text: true,
            },
        });

        // 4. Fetch Google Calendar Events for today
        let calendarEvents: any[] = [];
        try {
            const calendarUrl = `https://www.googleapis.com/calendar/v3/calendars/primary/events?timeMin=${encodeURIComponent(timeMin as string)}&timeMax=${encodeURIComponent(timeMax as string)}&singleEvents=true&orderBy=startTime`;
            const calendarResponse = await fetch(calendarUrl, {
                headers: {
                    Authorization: `Bearer ${accessToken}`,
                },
            });

            if (calendarResponse.ok) {
                const calendarData = await calendarResponse.json();
                if (calendarData.items) {
                    calendarEvents = calendarData.items.map((event: any) => ({
                        summary: event.summary || "No Title",
                        description: event.description || "",
                        start: event.start?.dateTime || event.start?.date || "",
                        end: event.end?.dateTime || event.end?.date || "",
                        location: event.location || "",
                    }));
                }
            } else {
                console.error("Failed to fetch Google Calendar events:", await calendarResponse.text());
            }
        } catch (calError) {
            console.error("Error fetching calendar events:", calError);
        }

        // 5. Fetch Google Tasks for today
        let tasks: any[] = [];
        try {
            const taskListResponse = await fetch("https://tasks.googleapis.com/tasks/v1/users/@me/lists", {
                headers: {
                    Authorization: `Bearer ${accessToken}`,
                },
            });

            if (taskListResponse.ok) {
                const taskListData = await taskListResponse.json();
                if (taskListData.items && taskListData.items.length > 0) {
                    const listId = taskListData.items[0].id;
                    const tasksResponse = await fetch(`https://tasks.googleapis.com/tasks/v1/lists/${listId}/tasks?showCompleted=false`, {
                        headers: {
                            Authorization: `Bearer ${accessToken}`,
                        },
                    });

                    if (tasksResponse.ok) {
                        const tasksData = await tasksResponse.json();
                        if (tasksData.items) {
                            tasks = tasksData.items.map((task: any) => ({
                                title: task.title || "Untitled Task",
                                notes: task.notes || "",
                                due: task.due || "",
                                status: task.status || "needsAction",
                            }));
                        }
                    } else {
                        console.error("Failed to fetch tasks from list:", await tasksResponse.text());
                    }
                }
            } else {
                console.error("Failed to fetch task lists:", await taskListResponse.text());
            }
        } catch (taskError) {
            console.error("Error fetching tasks:", taskError);
        }

        // 6. Fetch Gmail unread emails of today
        let emails: any[] = [];
        try {
            const unixSeconds = Math.floor(new Date(timeMin as string).getTime() / 1000);
            const gmailQuery = `is:unread after:${unixSeconds}`;
            const gmailUrl = `https://gmail.googleapis.com/gmail/v1/users/me/messages?q=${encodeURIComponent(gmailQuery)}`;

            const gmailResponse = await fetch(gmailUrl, {
                headers: {
                    Authorization: `Bearer ${accessToken}`,
                },
            });

            if (gmailResponse.ok) {
                const gmailData = await gmailResponse.json();
                if (gmailData.messages && gmailData.messages.length > 0) {
                    // Limit detail fetching to first 5 unread emails to keep request fast
                    const limitMessages = gmailData.messages.slice(0, 5);
                    for (const msg of limitMessages) {
                        const msgDetailsResponse = await fetch(`https://gmail.googleapis.com/gmail/v1/users/me/messages/${msg.id}`, {
                            headers: {
                                Authorization: `Bearer ${accessToken}`,
                            },
                        });

                        if (msgDetailsResponse.ok) {
                            const msgDetails = await msgDetailsResponse.json();
                            const headers = msgDetails.payload?.headers || [];
                            const subject = headers.find((h: any) => h.name.toLowerCase() === "subject")?.value || "No Subject";
                            const from = headers.find((h: any) => h.name.toLowerCase() === "from")?.value || "Unknown Sender";
                            const date = headers.find((h: any) => h.name.toLowerCase() === "date")?.value || "";

                            emails.push({
                                id: msgDetails.id,
                                threadId: msgDetails.threadId,
                                subject,
                                from,
                                date,
                                snippet: msgDetails.snippet || "",
                            });
                        }
                    }
                }
            } else {
                console.error("Failed to fetch Gmail list:", await gmailResponse.text());
            }
        } catch (gmailError) {
            console.error("Error fetching Gmail:", gmailError);
        }

        // 7. Request Report summary from Groq API (openai/gpt-oss-120b)
        const groqApiKey = process.env.GROQ_API_KEY;
        if (!groqApiKey) {
            console.error("Missing GROQ_API_KEY in .env");
            return ApiResponse(res, 500, "Server configuration error: AI service unavailable");
        }

        const systemPrompt = `You are Briefly, a personal AI executive assistant. Your task is to generate a daily report summarizing the user's data for today.
Here is the user's data for today:
- Floats (Stored wisdom / positive reminders): ${JSON.stringify(floats.map(f => f.text))}
- Tasks: ${JSON.stringify(tasks)}
- Calendar events: ${JSON.stringify(calendarEvents)}
- Unread emails: ${JSON.stringify(emails)}

Please output a valid, structured JSON response. You MUST use this exact JSON format:
{
  "summary": "A friendly, cohesive, and concise 2-3 sentence overview of the user's day based on their schedule and emails.",
  "wisdom": "A short, actionable insight or reminder synthesized from their Floats.",
  "tasks": [
    {
      "title": "Task title",
      "status": "needsAction" | "completed",
      "summary": "A 1-sentence explanation of what needs to be done."
    }
  ],
  "calendar": [
    {
      "title": "Event title",
      "time": "Event start time (e.g. 10:00 AM)",
      "summary": "A 1-sentence summary of the event."
    }
  ],
  "emails": [
    {
      "id": "Message ID",
      "threadId": "Thread ID",
      "subject": "Subject",
      "from": "Sender name/email",
      "summary": "A 1-sentence summary of what this email is about.",
      "link": "https://mail.google.com/mail/u/0/#inbox/{threadId}"
    }
  ]
}

Requirements:
1. Ensure all fields are filled. If any list (like calendar, tasks, emails, floats) is empty, return an empty array for that field. Still generate a friendly summary and wisdom (use general encouragement if no floats exist).
2. For emails, populate the "link" field exactly as "https://mail.google.com/mail/u/0/#inbox/{threadId}" replacing {threadId} with the email's threadId.
3. Return ONLY valid JSON. Do not wrap the JSON in markdown formatting or code blocks.`;

        console.log("Calling Groq API (openai/gpt-oss-120b) to generate report summary...");

        const groqResponse = await fetch("https://api.groq.com/openai/v1/chat/completions", {
            method: "POST",
            headers: {
                "Authorization": `Bearer ${groqApiKey}`,
                "Content-Type": "application/json",
            },
            body: JSON.stringify({
                model: "openai/gpt-oss-120b",
                messages: [
                    { role: "user", content: systemPrompt },
                ],
                response_format: { type: "json_object" },
                temperature: 0.3,
            }),
        });

        const groqData = await groqResponse.json();

        if (!groqResponse.ok) {
            console.error("Groq API error response:", groqData);
            return ApiResponse(res, 500, "Failed to compile AI summary report");
        }

        const aiContent = groqData.choices?.[0]?.message?.content;
        if (!aiContent) {
            return ApiResponse(res, 500, "No content generated from AI engine");
        }

        const parsedReport = JSON.parse(aiContent);
        console.log(`Daily report generated successfully for ${user.email}.`);

        return ApiResponse(res, 200, "Daily report retrieved successfully", parsedReport);

    } catch (error: any) {
        console.error("Error in getDailyReport controller:", error);
        return ApiResponse(res, 500, error.message || "An unexpected error occurred compiling your daily report");
    }
};

export { getDailyReport };
