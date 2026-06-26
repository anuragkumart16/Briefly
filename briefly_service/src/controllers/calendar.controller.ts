import { Request, Response } from "express";
import ApiResponse from "../utils/response.util";
import { getValidGoogleToken } from "../utils/google-token.util";

/**
 * Fetch Remaining Google Calendar Events for Today.
 */
export const getTodayLeftEvents = async (req: Request, res: Response) => {
    const userId = req.params.userId as string;
    const timeMin = req.query.timeMin as string; // Expects UTC ISO string
    const timeMax = req.query.timeMax as string; // Expects UTC ISO string

    if (!userId) {
        return ApiResponse(res, 400, "User ID is required");
    }
    if (!timeMin || !timeMax) {
        return ApiResponse(res, 400, "timeMin and timeMax query parameters are required");
    }

    try {
        const accessToken = await getValidGoogleToken(userId);

        const calendarUrl = `https://www.googleapis.com/calendar/v3/calendars/primary/events?timeMin=${encodeURIComponent(timeMin)}&timeMax=${encodeURIComponent(timeMax)}&singleEvents=true&orderBy=startTime`;
        const calendarResponse = await fetch(calendarUrl, {
            headers: { Authorization: `Bearer ${accessToken}` },
        });

        if (!calendarResponse.ok) {
            return ApiResponse(res, calendarResponse.status, "Google Calendar API error: " + await calendarResponse.text());
        }

        const calendarData = await calendarResponse.json();
        const items = calendarData.items || [];

        const now = new Date();
        const events = items
            .map((event: any) => {
                const startStr = event.start?.dateTime || event.start?.date || "";
                const endStr = event.end?.dateTime || event.end?.date || "";
                const startTime = startStr ? new Date(startStr) : null;
                const endTime = endStr ? new Date(endStr) : null;

                return {
                    id: event.id,
                    summary: event.summary || "No Title",
                    description: event.description || "",
                    start: startStr,
                    end: endStr,
                    startTime,
                    endTime,
                    location: event.location || "",
                    organizer: event.organizer?.displayName || event.organizer?.email || "",
                    attendees: (event.attendees || []).map((a: any) => ({
                        name: a.displayName || "",
                        email: a.email || "",
                        responseStatus: a.responseStatus || "",
                    })),
                    conferenceLink: event.conferenceData?.entryPoints?.[0]?.uri || "",
                    attachments: (event.attachments || []).map((att: any) => ({
                        title: att.title || "",
                        fileUrl: att.fileUrl || "",
                        mimeType: att.mimeType || "",
                    })),
                    status: event.status || "",
                };
            })
            // Filter events that haven't ended yet
            .filter((event: any) => {
                if (!event.endTime) return true; // Keep all-day events or events with missing time
                return event.endTime.getTime() > now.getTime();
            });

        return ApiResponse(res, 200, "Remaining calendar events retrieved successfully", events);
    } catch (error: any) {
        console.error("Error in getTodayLeftEvents:", error);
        return ApiResponse(res, 500, error.message || "Failed to fetch Google Calendar events");
    }
};
