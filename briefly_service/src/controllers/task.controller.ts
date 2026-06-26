import { Request, Response } from "express";
import ApiResponse from "../utils/response.util";
import { getValidGoogleToken } from "../utils/google-token.util";

/**
 * Gets the primary Google Task List ID for a user.
 */
async function getPrimaryTaskListId(accessToken: string): Promise<string> {
    const listResponse = await fetch("https://tasks.googleapis.com/tasks/v1/users/@me/lists", {
        headers: { Authorization: `Bearer ${accessToken}` },
    });

    if (!listResponse.ok) {
        throw new Error(`Failed to fetch Google task lists: ${await listResponse.text()}`);
    }

    const listData = await listResponse.json();
    if (!listData.items || listData.items.length === 0) {
        throw new Error("No Google task lists found for the user.");
    }

    return listData.items[0].id;
}

/**
 * Fetch Google Tasks from primary list.
 */
export const getTasks = async (req: Request, res: Response) => {
    const userId = req.params.userId as string;
    if (!userId) {
        return ApiResponse(res, 400, "User ID is required");
    }

    try {
        const accessToken = await getValidGoogleToken(userId);
        const listId = await getPrimaryTaskListId(accessToken);

        // Fetch both completed and uncompleted tasks
        const tasksResponse = await fetch(
            `https://tasks.googleapis.com/tasks/v1/lists/${listId}/tasks?showCompleted=true&showHidden=true`,
            {
                headers: { Authorization: `Bearer ${accessToken}` },
            }
        );

        if (!tasksResponse.ok) {
            return ApiResponse(res, tasksResponse.status, "Google Tasks API error: " + await tasksResponse.text());
        }

        const tasksData = await tasksResponse.json();
        const rawTasks = tasksData.items || [];

        // Map them cleanly for frontend consumption
        const tasks = rawTasks.map((task: any) => {
            const dueDate = task.due ? new Date(task.due) : null;
            const today = new Date();
            let daysUntilDue: number | null = null;
            if (dueDate) {
                daysUntilDue = Math.ceil((dueDate.getTime() - today.setHours(0,0,0,0)) / 86400000);
            }

            return {
                id: task.id,
                title: task.title || "",
                notes: task.notes || "",
                due: task.due || "",
                daysUntilDue,
                isOverdue: daysUntilDue !== null && daysUntilDue < 0 && task.status !== "completed",
                isDueToday: daysUntilDue === 0,
                status: task.status || "needsAction", // 'needsAction' or 'completed'
                updated: task.updated || "",
            };
        });

        return ApiResponse(res, 200, "Tasks retrieved successfully", tasks);
    } catch (error: any) {
        console.error("Error in getTasks:", error);
        return ApiResponse(res, 500, error.message || "Failed to fetch Google tasks");
    }
};

/**
 * Create a new task in the primary task list.
 */
export const createTask = async (req: Request, res: Response) => {
    const userId = req.params.userId as string;
    const { title, notes, due } = req.body;

    if (!userId) {
        return ApiResponse(res, 400, "User ID is required");
    }
    if (!title || !title.trim()) {
        return ApiResponse(res, 400, "Task title is required");
    }

    try {
        const accessToken = await getValidGoogleToken(userId);
        const listId = await getPrimaryTaskListId(accessToken);

        const body: any = {
            title: title.trim(),
        };
        if (notes !== undefined) body.notes = notes.trim();
        if (due !== undefined) body.due = due; // Must be RFC 3339 formatted e.g. "2026-06-26T00:00:00.000Z"

        const response = await fetch(`https://tasks.googleapis.com/tasks/v1/lists/${listId}/tasks`, {
            method: "POST",
            headers: {
                Authorization: `Bearer ${accessToken}`,
                "Content-Type": "application/json",
            },
            body: JSON.stringify(body),
        });

        if (!response.ok) {
            return ApiResponse(res, response.status, "Google Tasks API error: " + await response.text());
        }

        const task = await response.json();
        return ApiResponse(res, 201, "Task created successfully in Google Tasks", {
            id: task.id,
            title: task.title || "",
            notes: task.notes || "",
            due: task.due || "",
            status: task.status || "needsAction",
        });
    } catch (error: any) {
        console.error("Error in createTask:", error);
        return ApiResponse(res, 500, error.message || "Failed to create Google task");
    }
};

/**
 * Update a Google Task by ID.
 */
export const updateTask = async (req: Request, res: Response) => {
    const userId = req.params.userId as string;
    const taskId = req.params.taskId as string;
    const { title, notes, due, status } = req.body;

    if (!userId || !taskId) {
        return ApiResponse(res, 400, "User ID and Task ID are required");
    }

    try {
        const accessToken = await getValidGoogleToken(userId);
        const listId = await getPrimaryTaskListId(accessToken);

        // Google Tasks PATCH requires matching fields.
        // If status changes to completed, Google Tasks API updates completed timestamp automatically.
        const body: any = {};
        if (title !== undefined) body.title = title.trim();
        if (notes !== undefined) body.notes = notes.trim();
        if (due !== undefined) body.due = due || null;
        if (status !== undefined) body.status = status; // 'needsAction' or 'completed'

        const response = await fetch(`https://tasks.googleapis.com/tasks/v1/lists/${listId}/tasks/${taskId}`, {
            method: "PATCH",
            headers: {
                Authorization: `Bearer ${accessToken}`,
                "Content-Type": "application/json",
            },
            body: JSON.stringify(body),
        });

        if (!response.ok) {
            return ApiResponse(res, response.status, "Google Tasks API error: " + await response.text());
        }

        const task = await response.json();
        return ApiResponse(res, 200, "Task updated successfully in Google Tasks", {
            id: task.id,
            title: task.title || "",
            notes: task.notes || "",
            due: task.due || "",
            status: task.status || "needsAction",
        });
    } catch (error: any) {
        console.error("Error in updateTask:", error);
        return ApiResponse(res, 500, error.message || "Failed to update Google task");
    }
};

/**
 * Delete a Google Task by ID.
 */
export const deleteTask = async (req: Request, res: Response) => {
    const userId = req.params.userId as string;
    const taskId = req.params.taskId as string;

    if (!userId || !taskId) {
        return ApiResponse(res, 400, "User ID and Task ID are required");
    }

    try {
        const accessToken = await getValidGoogleToken(userId);
        const listId = await getPrimaryTaskListId(accessToken);

        const response = await fetch(`https://tasks.googleapis.com/tasks/v1/lists/${listId}/tasks/${taskId}`, {
            method: "DELETE",
            headers: {
                Authorization: `Bearer ${accessToken}`,
            },
        });

        if (!response.ok) {
            return ApiResponse(res, response.status, "Google Tasks API error: " + await response.text());
        }

        return ApiResponse(res, 200, "Task deleted successfully from Google Tasks");
    } catch (error: any) {
        console.error("Error in deleteTask:", error);
        return ApiResponse(res, 500, error.message || "Failed to delete Google task");
    }
};
