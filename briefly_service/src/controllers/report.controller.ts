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
        // 1. Get user details and settings from the database
        const [user, settings] = await Promise.all([
            prisma.user.findUnique({ where: { id: userId } }),
            prisma.settings.findUnique({ where: { userId } }),
        ]);

        if (!user) {
            return ApiResponse(res, 404, "User not found");
        }

        // Use settings flags (default true if no settings record exists yet)
        const includeFloats   = settings?.reportIncludeFloats   ?? true;
        const includeCalendar = settings?.reportIncludeCalendar ?? true;
        const includeTasks    = settings?.reportIncludeTasks    ?? true;
        const includeEmails   = settings?.reportIncludeEmails   ?? true;

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

        // 3. Fetch user's active Floats from DB (if enabled)
        let floats: { text: string }[] = [];
        if (includeFloats) {
            floats = await prisma.floatItem.findMany({
                where: { userId, isActive: true },
                select: { text: true },
            });
        }

        // 4. Fetch Google Calendar Events for today (if enabled)
        let calendarEvents: any[] = [];
        if (includeCalendar) {
            try {
                const calendarUrl = `https://www.googleapis.com/calendar/v3/calendars/primary/events?timeMin=${encodeURIComponent(timeMin as string)}&timeMax=${encodeURIComponent(timeMax as string)}&singleEvents=true&orderBy=startTime`;
                const calendarResponse = await fetch(calendarUrl, {
                    headers: { Authorization: `Bearer ${accessToken}` },
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
                            organizer: event.organizer?.displayName || event.organizer?.email || "",
                            attendees: (event.attendees || []).map((a: any) => a.displayName || a.email).slice(0, 5),
                            conferenceLink: event.conferenceData?.entryPoints?.[0]?.uri || "",
                            status: event.status || "",
                        }));
                    }
                } else {
                    console.error("Failed to fetch Google Calendar events:", await calendarResponse.text());
                }
            } catch (calError) {
                console.error("Error fetching calendar events:", calError);
            }
        }

        // 5. Fetch Google Tasks for today (if enabled)
        let tasks: any[] = [];
        if (includeTasks) {
            try {
                const taskListResponse = await fetch("https://tasks.googleapis.com/tasks/v1/users/@me/lists", {
                    headers: { Authorization: `Bearer ${accessToken}` },
                });

                if (taskListResponse.ok) {
                    const taskListData = await taskListResponse.json();
                    if (taskListData.items && taskListData.items.length > 0) {
                        const listId = taskListData.items[0].id;
                        const tasksResponse = await fetch(`https://tasks.googleapis.com/tasks/v1/lists/${listId}/tasks?showCompleted=false`, {
                            headers: { Authorization: `Bearer ${accessToken}` },
                        });

                        if (tasksResponse.ok) {
                            const tasksData = await tasksResponse.json();
                            if (tasksData.items) {
                                tasks = tasksData.items.map((task: any) => {
                                    const dueDate = task.due ? new Date(task.due) : null;
                                    const today = new Date();
                                    const daysUntilDue = dueDate
                                        ? Math.ceil((dueDate.getTime() - today.setHours(0,0,0,0)) / 86400000)
                                        : null;
                                    return {
                                        title: task.title || "Untitled Task",
                                        notes: task.notes || "",
                                        due: task.due || "",
                                        daysUntilDue,
                                        isOverdue: daysUntilDue !== null && daysUntilDue < 0,
                                        isDueToday: daysUntilDue === 0,
                                        status: task.status || "needsAction",
                                    };
                                });
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
        }

        // 6. Fetch Gmail unread emails of today (if enabled)
        let emails: any[] = [];
        if (includeEmails) {
            try {
                const unixSeconds = Math.floor(new Date(timeMin as string).getTime() / 1000);
                // Exclude obvious bulk/promotional senders; AI will also filter further
                const gmailQuery = `is:unread after:${unixSeconds} -category:promotions -category:social`;
                const gmailUrl = `https://gmail.googleapis.com/gmail/v1/users/me/messages?q=${encodeURIComponent(gmailQuery)}&maxResults=10`;

                const gmailResponse = await fetch(gmailUrl, {
                    headers: { Authorization: `Bearer ${accessToken}` },
                });

                if (gmailResponse.ok) {
                    const gmailData = await gmailResponse.json();
                    if (gmailData.messages && gmailData.messages.length > 0) {
                        // Fetch up to 10 messages; AI will pick top 5 important ones
                        const limitMessages = gmailData.messages.slice(0, 10);
                        for (const msg of limitMessages) {
                            const msgDetailsResponse = await fetch(`https://gmail.googleapis.com/gmail/v1/users/me/messages/${msg.id}?format=metadata&metadataHeaders=Subject&metadataHeaders=From&metadataHeaders=Date&metadataHeaders=List-Unsubscribe`, {
                                headers: { Authorization: `Bearer ${accessToken}` },
                            });

                            if (msgDetailsResponse.ok) {
                                const msgDetails = await msgDetailsResponse.json();
                                const headers = msgDetails.payload?.headers || [];
                                const subject = headers.find((h: any) => h.name.toLowerCase() === "subject")?.value || "No Subject";
                                const from = headers.find((h: any) => h.name.toLowerCase() === "from")?.value || "Unknown Sender";
                                const date = headers.find((h: any) => h.name.toLowerCase() === "date")?.value || "";
                                const hasUnsubscribe = headers.some((h: any) => h.name.toLowerCase() === "list-unsubscribe");

                                emails.push({
                                    id: msgDetails.id,
                                    threadId: msgDetails.threadId,
                                    subject,
                                    from,
                                    date,
                                    snippet: msgDetails.snippet || "",
                                    likelyNewsletter: hasUnsubscribe,
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
        }

        // 7. Request Report summary from Groq API (openai/gpt-oss-120b)
        const groqApiKey = process.env.GROQ_API_KEY;
        if (!groqApiKey) {
            console.error("Missing GROQ_API_KEY in .env");
            return ApiResponse(res, 500, "Server configuration error: AI service unavailable");
        }

        // Build AI prompt dynamically based on enabled sections
        const dataLines: string[] = [];
        if (includeFloats)   dataLines.push(`- Floats (Stored wisdom / positive reminders): ${JSON.stringify(floats.map(f => f.text))}`);
        if (includeTasks)    dataLines.push(`- Tasks: ${JSON.stringify(tasks)}`);
        if (includeCalendar) dataLines.push(`- Calendar events: ${JSON.stringify(calendarEvents)}`);
        if (includeEmails)   dataLines.push(`- Unread emails: ${JSON.stringify(emails)}`);

        // Build the JSON schema sections that should appear in the response
        const schemaSections: string[] = [
            `  "summary": "A friendly, cohesive 2-3 sentence overview of the user's day, mentioning urgent deadlines and key events.",`,
        ];
        if (includeFloats)   schemaSections.push(`  "wisdom": "A short actionable insight synthesized from their Floats. Empty string if no floats.",`);
        if (includeTasks)    schemaSections.push(`  "tasks": [ { "title": "Task title", "status": "needsAction|completed", "deadline": "Human-readable deadline e.g. 'Due today', 'Overdue by 2 days', 'Due in 3 days', or '' if no due date", "summary": "1-sentence description of what needs doing and why it matters." } ],`);
        if (includeCalendar) schemaSections.push(`  "calendar": [ { "title": "Event title", "time": "e.g. 10:00 AM", "location": "Location or video link if available, else empty string", "attendees": "Comma-separated list of attendees if any, else empty string", "summary": "1-sentence summary covering what the event is and what to prepare." } ],`);
        if (includeEmails)   schemaSections.push(`  "emails": [ { "id": "msg id", "threadId": "thread id", "subject": "Subject", "from": "Sender display name only", "priority": "high|medium", "summary": "2-sentence summary of what this email is about and what action (if any) is needed.", "link": "https://mail.google.com/mail/u/0/#inbox/{threadId}" } ]`);

        const systemPrompt = `You are Briefly, a personal AI executive assistant. Generate a focused daily report for the user.
Here is today's data:
${dataLines.join("\n")}

Return ONLY valid JSON (no markdown, no code blocks) in this exact shape:
{
${schemaSections.join("\n")}
}

Rules:
1. Omit any key not listed in the shape above.
2. Return empty arrays [] for list fields that have no data.
3. For email links use exactly: https://mail.google.com/mail/u/0/#inbox/{threadId}
4. If wisdom is included but no floats exist, use a short general motivational insight.
5. For tasks: always fill the "deadline" field. Use 'Overdue' if isOverdue=true, 'Due today' if isDueToday=true, 'Due in N days' if daysUntilDue>0, else empty string.
6. For emails: EXCLUDE newsletters, marketing, and automated notifications (likelyNewsletter=true or obvious spam). Only include genuine human-sent or important system emails. Return at most 5.
7. For emails: set "priority" to "high" if the email requires action or is time-sensitive, else "medium".
8. For calendar: include location and attendees fields when available from the data; use empty string if missing.`;

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
