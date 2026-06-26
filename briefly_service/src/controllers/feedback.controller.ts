import { Request, Response } from "express";
import ApiResponse from "../utils/response.util";
import prisma from "../config/prisma";

/**
 * Submit User Feedback.
 * 
 * Creates a feedback record in MongoDB database.
 * 
 * @param req express request object
 * @param res express response object
 */
const submitFeedback = async (req: Request, res: Response) => {
    const { userId, email, text } = req.body;

    if (!text) {
        return ApiResponse(res, 400, "Feedback text is required");
    }

    try {
        const feedback = await prisma.feedback.create({
            data: {
                userId: userId || null,
                email: email || null,
                text,
            },
        });

        console.log(`Feedback stored successfully for: ${email || "anonymous"} (User ID: ${userId || "none"})`);

        return ApiResponse(res, 201, "Feedback submitted successfully", feedback);
    } catch (error: any) {
        console.error("Error in submitFeedback controller:", error);
        return ApiResponse(res, 500, error.message || "Failed to submit feedback");
    }
};

export { submitFeedback };
