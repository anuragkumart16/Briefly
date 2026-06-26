import { Request, Response } from "express";
import ApiResponse from "../utils/response.util";
import { getValidGoogleToken } from "../utils/google-token.util";

/**
 * Fetch Today's Unread Emails.
 */
export const getTodayEmails = async (req: Request, res: Response) => {
    const userId = req.params.userId as string;
    const timeMin = req.query.timeMin as string; // Expects UTC ISO string

    if (!userId) {
        return ApiResponse(res, 400, "User ID is required");
    }
    if (!timeMin) {
        return ApiResponse(res, 400, "timeMin query parameter is required");
    }

    try {
        const accessToken = await getValidGoogleToken(userId);
        const unixSeconds = Math.floor(new Date(timeMin).getTime() / 1000);
        // Clean query excluding spam category
        const gmailQuery = `is:unread after:${unixSeconds} -category:promotions -category:social`;
        const gmailUrl = `https://gmail.googleapis.com/gmail/v1/users/me/messages?q=${encodeURIComponent(gmailQuery)}&maxResults=10`;

        const gmailResponse = await fetch(gmailUrl, {
            headers: { Authorization: `Bearer ${accessToken}` },
        });

        if (!gmailResponse.ok) {
            return ApiResponse(res, gmailResponse.status, "Gmail API error: " + await gmailResponse.text());
        }

        const gmailData = await gmailResponse.json();
        const rawMessages = gmailData.messages || [];
        const emails: any[] = [];

        for (const msg of rawMessages) {
            // Fetch detailed message formatting to extract sender display, headers, body, attachments
            const msgDetailsResponse = await fetch(
                `https://gmail.googleapis.com/gmail/v1/users/me/messages/${msg.id}?format=full`,
                { headers: { Authorization: `Bearer ${accessToken}` } }
            );

            if (msgDetailsResponse.ok) {
                const msgDetails = await msgDetailsResponse.json();
                const headers = msgDetails.payload?.headers || [];
                const subject = headers.find((h: any) => h.name.toLowerCase() === "subject")?.value || "No Subject";
                const from = headers.find((h: any) => h.name.toLowerCase() === "from")?.value || "Unknown Sender";
                const date = headers.find((h: any) => h.name.toLowerCase() === "date")?.value || "";
                
                // Parse potential attachments metadata
                const attachments: any[] = [];
                const parts = msgDetails.payload?.parts || [];
                const checkParts = (partList: any[]) => {
                    for (const part of partList) {
                        if (part.filename && part.body?.attachmentId) {
                            attachments.push({
                                filename: part.filename,
                                mimeType: part.mimeType || "",
                                size: part.body.size || 0,
                                attachmentId: part.body.attachmentId,
                                link: `https://mail.google.com/mail/u/0/#inbox/${msgDetails.threadId}`,
                            });
                        }
                        if (part.parts) {
                            checkParts(part.parts);
                        }
                    }
                };
                checkParts(parts);

                emails.push({
                    id: msgDetails.id,
                    threadId: msgDetails.threadId,
                    subject,
                    from,
                    date,
                    snippet: msgDetails.snippet || "",
                    attachments,
                    link: `https://mail.google.com/mail/u/0/#inbox/${msgDetails.threadId}`,
                });
            }
        }

        return ApiResponse(res, 200, "Today's unread emails retrieved successfully", emails);
    } catch (error: any) {
        console.error("Error in getTodayEmails:", error);
        return ApiResponse(res, 500, error.message || "Failed to fetch Gmail unread messages");
    }
};
