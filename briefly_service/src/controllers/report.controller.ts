import { Request, Response } from "express";
import ApiResponse from "../utils/response.util";
import prisma from "../config/prisma";
import { appConfig } from "../config/envConfig";

import { getValidGoogleToken } from "../utils/google-token.util";
import { sendNotificationToUser } from "../services/fcm.service";

/**
 * Calculates start and end dates of today in the user's timezone and returns their UTC ISO strings.
 */
function getLocalDayRange(timezone: string = "Asia/Kolkata") {
    const tzDate = new Date();
    const tzString = tzDate.toLocaleString("en-US", { timeZone: timezone });
    const localDate = new Date(tzString);
    
    const year = localDate.getFullYear();
    const month = String(localDate.getMonth() + 1).padStart(2, '0');
    const day = String(localDate.getDate()).padStart(2, '0');
    
    const minStr = `${year}-${month}-${day}T00:00:00`;
    const maxStr = `${year}-${month}-${day}T23:59:59.999`;
    
    const getUtcDate = (dateStr: string) => {
        const invDate = new Date(new Date(dateStr).toLocaleString("en-US", { timeZone: timezone }));
        const diff = new Date(dateStr).getTime() - invDate.getTime();
        return new Date(new Date(dateStr).getTime() + diff);
    };
    
    return {
        timeMin: getUtcDate(minStr).toISOString(),
        timeMax: getUtcDate(maxStr).toISOString()
    };
}

/**
 * Calculates the UTC Date representing the user's scheduled report time for a given base date and timezone.
 */
function getSetReportTime(baseDate: Date, timezone: string, reportHour: number, reportMinute: number): Date {
    const tzString = baseDate.toLocaleString("en-US", { timeZone: timezone });
    const localDate = new Date(tzString);
    
    const year = localDate.getFullYear();
    const month = String(localDate.getMonth() + 1).padStart(2, '0');
    const day = String(localDate.getDate()).padStart(2, '0');
    
    const setTimeStr = `${year}-${month}-${day}T${String(reportHour).padStart(2, '0')}:${String(reportMinute).padStart(2, '0')}:00`;
    
    const getUtcDate = (dateStr: string) => {
        const invDate = new Date(new Date(dateStr).toLocaleString("en-US", { timeZone: timezone }));
        const diff = new Date(dateStr).getTime() - invDate.getTime();
        return new Date(new Date(dateStr).getTime() + diff);
    };
    
    return getUtcDate(setTimeStr);
}

/**
 * Core helper to compile the daily report via Groq API.
 */
export async function compileDailyReport(userId: string, timeMin: string, timeMax: string, anchorTime?: Date): Promise<any> {
    // 1. Get user details and settings from the database
    const [user, settings] = await Promise.all([
        prisma.user.findUnique({ where: { id: userId } }),
        prisma.settings.findUnique({ where: { userId } }),
    ]);

    if (!user) {
        throw new Error("User not found");
    }

    // Use settings flags (default true if no settings record exists yet)
    const includeFloats   = settings?.reportIncludeFloats   ?? true;
    const includeCalendar = settings?.reportIncludeCalendar ?? true;
    const includeTasks    = settings?.reportIncludeTasks    ?? true;
    const includeEmails   = settings?.reportIncludeEmails   ?? true;
    const markEmailsUnread = settings?.markEmailsUnread     ?? true;

    const timezone = settings?.timezone || "Asia/Kolkata";
    const reportHour = settings?.reportHour ?? 20;
    const reportMinute = settings?.reportMinute ?? 30;

    const baseDate = timeMin ? new Date(timeMin) : new Date();
    const setReportTime = anchorTime || getSetReportTime(baseDate, timezone, reportHour, reportMinute);

    // 2. Resolve a valid, non-expired Google Access Token
    const accessToken = await getValidGoogleToken(userId);

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
            const calendarTimeMin = setReportTime.toISOString();
            const calendarTimeMax = new Date(setReportTime.getTime() + 24 * 60 * 60 * 1000).toISOString();
            const calendarUrl = `https://www.googleapis.com/calendar/v3/calendars/primary/events?timeMin=${encodeURIComponent(calendarTimeMin)}&timeMax=${encodeURIComponent(calendarTimeMax)}&singleEvents=true&orderBy=startTime`;
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
                        attendees: (event.attendees || []).map((a: any) => a.displayName || a.email),
                        attachments: (event.attachments || []).map((att: any) => ({
                            title: att.title || "Untitled Attachment",
                            fileUrl: att.fileUrl || ""
                        })),
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
                                const refDate = new Date(setReportTime);
                                refDate.setHours(0, 0, 0, 0);
                                const daysUntilDue = dueDate
                                    ? Math.ceil((dueDate.getTime() - refDate.getTime()) / 86400000)
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
            const emailStartUnix = Math.floor((setReportTime.getTime() - 24 * 60 * 60 * 1000) / 1000);
            const gmailQuery = `is:unread after:${emailStartUnix} -category:promotions -category:social`;
            const gmailUrl = `https://gmail.googleapis.com/gmail/v1/users/me/messages?q=${encodeURIComponent(gmailQuery)}&maxResults=10`;

            const gmailResponse = await fetch(gmailUrl, {
                headers: { Authorization: `Bearer ${accessToken}` },
            });

            if (gmailResponse.ok) {
                const gmailData = await gmailResponse.json();
                if (gmailData.messages && gmailData.messages.length > 0) {
                    const limitMessages = gmailData.messages.slice(0, 10);
                    for (const msg of limitMessages) {
                        const msgDetailsResponse = await fetch(`https://gmail.googleapis.com/gmail/v1/users/me/messages/${msg.id}?format=full`, {
                            headers: { Authorization: `Bearer ${accessToken}` },
                        });

                        if (msgDetailsResponse.ok) {
                            const msgDetails = await msgDetailsResponse.json();
                            const headers = msgDetails.payload?.headers || [];
                            const subject = headers.find((h: any) => h.name.toLowerCase() === "subject")?.value || "No Subject";
                            const from = headers.find((h: any) => h.name.toLowerCase() === "from")?.value || "Unknown Sender";
                            const date = headers.find((h: any) => h.name.toLowerCase() === "date")?.value || "";
                            const hasUnsubscribe = headers.some((h: any) => h.name.toLowerCase() === "list-unsubscribe");

                            const attachments: any[] = [];
                            const checkParts = (partList: any[]) => {
                                for (const part of partList) {
                                    if (part.filename && part.body?.attachmentId) {
                                        attachments.push({
                                            name: part.filename,
                                            link: `https://mail.google.com/mail/u/0/#inbox/${msgDetails.threadId}`
                                        });
                                    }
                                    if (part.parts) {
                                        checkParts(part.parts);
                                    }
                                }
                            };
                            if (msgDetails.payload?.parts) {
                                checkParts(msgDetails.payload.parts);
                            }

                            emails.push({
                                id: msgDetails.id,
                                threadId: msgDetails.threadId,
                                subject,
                                from,
                                date,
                                snippet: msgDetails.snippet || "",
                                likelyNewsletter: hasUnsubscribe,
                                attachments,
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
    const groqApiKey = appConfig.groqApiKey;
    if (!groqApiKey) {
        throw new Error("Server configuration error: AI service unavailable");
    }

    const dataLines: string[] = [];
    if (includeFloats)   dataLines.push(`- Floats (Stored wisdom / positive reminders): ${JSON.stringify(floats.map(f => f.text))}`);
    if (includeTasks)    dataLines.push(`- Tasks: ${JSON.stringify(tasks)}`);
    if (includeCalendar) dataLines.push(`- Calendar events: ${JSON.stringify(calendarEvents)}`);
    if (includeEmails)   dataLines.push(`- Unread emails: ${JSON.stringify(emails)}`);

    const schemaSections: string[] = [
        `  "summary": "A friendly, cohesive 2-3 sentence overview of the user's day, mentioning urgent deadlines and key events.",`,
    ];
    if (includeFloats)   schemaSections.push(`  "wisdom": "A short actionable insight synthesized from their Floats. Empty string if no floats.",`);
    if (includeTasks)    schemaSections.push(`  "tasks": [ { "title": "Task title", "status": "needsAction|completed", "deadline": "Human-readable deadline or 'No deadline' if not set", "details": "The details/description of the task if available, else empty string." } ],`);
    if (includeCalendar) schemaSections.push(`  "calendar": [ { "title": "Event title", "time": "e.g. 10:00 AM", "location": "Location or video link if available, else empty string", "attendees": "Comma-separated list of attendees names/emails if any, else 'Only you'", "documentLinks": [ { "title": "Document title", "link": "Direct link" } ], "summary": "1-sentence summary covering what the event is and what to prepare." } ],`);
    if (includeEmails)   schemaSections.push(`  "emails": [ { "id": "msg id", "threadId": "thread id", "subject": "Subject", "from": "Sender display name only", "priority": "high|medium", "crux": "Main point of the email", "whySent": "Why the email was sent", "summary": "Cohesive summary of the email", "link": "https://mail.google.com/mail/u/0/#inbox/{threadId}", "attachments": [ { "name": "Filename", "link": "Direct link" } ] } ]`);

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
5. For tasks: always fill the "deadline" field. If there is no deadline, specify 'No deadline'. Include the task's notes/details in the "details" field if they are available.
6. For calendar: if multiple people are joining, list their names/emails in "attendees". If there are documents/attachments, list them under "documentLinks".
7. For emails: provide a good summary of each, tell the crux along with who sent it, why they sent it, and list attachment files under "attachments" with their links.
8. Exclude emails that are newsletters, promotions, or spam.`;

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
        throw new Error("Failed to compile AI summary report");
    }

    const aiContent = groqData.choices?.[0]?.message?.content;
    if (!aiContent) {
        throw new Error("No content generated from AI engine");
    }

    const parsedReport = JSON.parse(aiContent);
    console.log(`Daily report generated successfully for ${user.email}.`);

    // 8. If enabled, mark the fetched emails back as UNREAD (fire-and-forget)
    if (markEmailsUnread && emails.length > 0 && accessToken) {
        const emailIds = emails.map((e: any) => e.id).filter(Boolean);
        if (emailIds.length > 0) {
            Promise.all(
                emailIds.map((msgId: string) =>
                    fetch(`https://gmail.googleapis.com/gmail/v1/users/me/messages/${msgId}/modify`, {
                        method: "POST",
                        headers: {
                            Authorization: `Bearer ${accessToken}`,
                            "Content-Type": "application/json",
                        },
                        body: JSON.stringify({ addLabelIds: ["UNREAD"] }),
                    }).catch((err) => console.error(`Failed to mark email ${msgId} as unread:`, err))
                )
            ).catch(() => {});
        }
    }

    return parsedReport;
}

/**
 * Generate and Fetch the Daily Report (from Cache or Dynamic compile).
 */
const getDailyReport = async (req: Request, res: Response) => {
    const userId = req.params.userId as string;
    const timeMin = req.query.timeMin as string;
    const timeMax = req.query.timeMax as string;
    const refresh = req.query.refresh === "true";

    if (!userId) {
        return ApiResponse(res, 400, "User ID is required");
    }

    if (!timeMin || !timeMax) {
        return ApiResponse(res, 400, "timeMin and timeMax query parameters are required");
    }

    try {
        if (!refresh) {
            // Try to retrieve cached report for today first
            const todayReport = await prisma.report.findFirst({
                where: {
                    userId,
                    createdAt: {
                        gte: new Date(timeMin),
                        lte: new Date(timeMax)
                    }
                },
                orderBy: { createdAt: "desc" }
            });

            if (todayReport) {
                console.log(`Returning cached report for user ${userId} from database.`);
                return ApiResponse(res, 200, "Daily report retrieved successfully", todayReport.data);
            }
        }

        console.log(refresh ? `Bypassing cache due to refresh request. Compiling fresh report for user ${userId}...` : `No cached report found. Compiling fresh report for user ${userId}...`);
        const parsedReport = await compileDailyReport(userId, timeMin, timeMax, refresh ? new Date() : undefined);

        // Cache in the database so next fetch gets it instantly
        await prisma.report.create({
            data: {
                userId,
                data: parsedReport
            }
        });

        return ApiResponse(res, 200, "Daily report retrieved successfully", parsedReport);

    } catch (error: any) {
        console.error("Error in getDailyReport controller:", error);
        return ApiResponse(res, 500, error.message || "An unexpected error occurred compiling your daily report");
    }
};

/**
 * Triggered by cron job once in 24 hours. Generates the report, stores in DB, and dispatches an FCM notification.
 */
const triggerDailyReport = async (req: Request, res: Response) => {
    const userId = req.params.userId as string;

    if (!userId) {
        return ApiResponse(res, 400, "User ID is required");
    }

    try {
        const settings = await prisma.settings.findUnique({
            where: { userId }
        });
        const timezone = settings?.timezone || "Asia/Kolkata";

        const { timeMin, timeMax } = getLocalDayRange(timezone);
        console.log(`Triggering daily report for user ${userId} in timezone ${timezone} (${timeMin} to ${timeMax})`);

        const parsedReport = await compileDailyReport(userId, timeMin, timeMax);

        const report = await prisma.report.create({
            data: {
                userId,
                data: parsedReport
            }
        });

        console.log(`Sending FCM notification to user ${userId} for report ${report.id}...`);
        await sendNotificationToUser(
            userId,
            "Your Daily Report is Ready! ✨",
            "Click to view your personalized daily summary.",
            {
                type: "daily_report",
                reportId: report.id
            }
        );

        return ApiResponse(res, 200, "Daily report triggered and sent successfully", { reportId: report.id });
    } catch (error: any) {
        console.error("Error in triggerDailyReport:", error);
        return ApiResponse(res, 500, error.message || "Failed to trigger daily report");
    }
};

export { getDailyReport, triggerDailyReport };
