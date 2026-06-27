import prisma from "../config/prisma";
import { appConfig } from "../config/envConfig";


export enum JobStatus {
    UNKNOWN = 0,
    OK = 1,
    FAILED_DNS = 2,
    FAILED_CONNECT = 3,
    FAILED_HTTP = 4,
    FAILED_TIMEOUT = 5,
    FAILED_TOO_MUCH_DATA = 6,
    FAILED_INVALID_URL = 7,
    FAILED_INTERNAL = 8,
    FAILED_UNKNOWN = 9
}

export enum JobType {
    DEFAULT = 0,
    MONITORING = 1
}

export enum RequestMethod {
    GET = 0,
    POST = 1,
    OPTIONS = 2,
    HEAD = 3,
    PUT = 4,
    DELETE = 5,
    TRACE = 6,
    CONNECT = 7,
    PATCH = 8
}

export interface JobSchedule {
    timezone?: string;
    expiresAt?: number;
    hours?: number[];
    mdays?: number[];
    minutes?: number[];
    months?: number[];
    wdays?: number[];
}

export interface JobAuth {
    enable?: boolean;
    user?: string;
    password?: string;
}

export interface JobNotificationSettings {
    onFailure?: boolean;
    onFailureCount?: number;
    onSuccess?: boolean;
    onDisable?: boolean;
    onSslCertExpiry?: boolean;
    onSslCertExpirySeconds?: number;
}

export interface JobExtendedData {
    headers?: Record<string, string>;
    body?: string;
}

export interface Job {
    jobId?: number;
    enabled?: boolean;
    title?: string;
    saveResponses?: boolean;
    url: string;
    lastStatus?: JobStatus;
    lastDuration?: number;
    lastExecution?: number;
    sslCertExpiry?: number;
    nextExecution?: number | null;
    type?: JobType;
    requestTimeout?: number;
    redirectSuccess?: boolean;
    folderId?: number;
    schedule?: JobSchedule;
    requestMethod?: RequestMethod;
}

export interface DetailedJob extends Job {
    auth?: JobAuth;
    notification?: JobNotificationSettings;
    extendedData?: JobExtendedData;
}

export interface Folder {
    folderId?: number;
    title: string;
}

export interface HistoryItemStats {
    nameLookup: number;
    connect: number;
    appConnect: number;
    preTransfer: number;
    startTransfer: number;
    total: number;
}

export interface HistoryItem {
    jobId: number;
    identifier: string;
    date: number;
    datePlanned: number;
    jitter: number;
    url: string;
    duration: number;
    status: JobStatus;
    statusText: string;
    httpStatus: number;
    headers: string | null;
    body: string | null;
    stats: HistoryItemStats;
    sslCertExpiry?: number;
}

const base_url : string = "https://api.cron-job.org"

const headers = {
    'Authorization': `Bearer ${appConfig.cronJobToken}`,
    'Content-Type': 'application/json'
}

async function handleResponse<T>(response: Response): Promise<T> {
    if (!response.ok) {
        let errorBody = "";
        try {
            errorBody = await response.text();
        } catch {}
        throw new Error(`HTTP error! status: ${response.status}, message: ${errorBody || response.statusText}`);
    }
    return response.json() as Promise<T>;
}

/**
 * Lists all cron jobs present in the account.
 * 
 * @example
 * ```typescript
 * const { jobs, someFailed } = await listCronJobs();
 * console.log(`Total jobs: ${jobs.length}`);
 * ```
 */
export async function listCronJobs(): Promise<{ jobs: Job[]; someFailed: boolean }> {
    const response = await fetch(`${base_url}/jobs`, {
        method: "GET",
        headers
    });
    return handleResponse<{ jobs: Job[]; someFailed: boolean }>(response);
}

/**
 * Retrieves detailed information of a specific cron job by its ID.
 * 
 * @param id - The ID of the cron job (e.g. "12345")
 * 
 * @example
 * ```typescript
 * const job = await getCronByID("12345");
 * console.log(`Job URL: ${job.url}`);
 * ```
 */
export async function getCronByID(id:string){
    const response = await fetch(`${base_url}/jobs/${id}`, {
        method: "GET",
        headers
    });
    const data = await handleResponse<{ jobDetails: DetailedJob }>(response);
    return data.jobDetails;
}

/**
 * Creates a new cron job.
 * 
 * @param job - The detailed configuration of the cron job to create
 * @returns The ID of the newly created cron job
 * 
 * @example
 * ```typescript
 * const jobId = await createCronJob({
 *   url: "https://example.com/webhook",
 *   enabled: true,
 *   schedule: {
 *     timezone: "UTC",
 *     hours: [-1], // every hour
 *     minutes: [0, 30] // at :00 and :30
 *   }
 * });
 * ```
 */
export async function createCronJob(job: DetailedJob): Promise<number> {
    const response = await fetch(`${base_url}/jobs`, {
        method: "PUT",
        headers,
        body: JSON.stringify({ job })
    });
    const data = await handleResponse<{ jobId: number }>(response);
    return data.jobId;
}

/**
 * Updates an existing cron job with the provided changed fields.
 * 
 * @param id - The ID of the cron job to update
 * @param jobDelta - The partial fields of the job to update
 * 
 * @example
 * ```typescript
 * await updateCronJob("12345", { enabled: false });
 * ```
 */
export async function updateCronJob(id: string, jobDelta: Partial<DetailedJob>): Promise<void> {
    const response = await fetch(`${base_url}/jobs/${id}`, {
        method: "PATCH",
        headers,
        body: JSON.stringify({ job: jobDelta })
    });
    await handleResponse<Record<string, never>>(response);
}

/**
 * Deletes a cron job by its ID.
 * 
 * @param id - The ID of the cron job to delete
 * 
 * @example
 * ```typescript
 * await deleteCronJob("12345");
 * ```
 */
export async function deleteCronJob(id: string): Promise<void> {
    const response = await fetch(`${base_url}/jobs/${id}`, {
        method: "DELETE",
        headers
    });
    await handleResponse<Record<string, never>>(response);
}

/**
 * Retrieves the execution history and next execution predictions for a specific cron job.
 * 
 * @param id - The ID of the cron job
 * 
 * @example
 * ```typescript
 * const { history, predictions } = await getCronJobHistory("12345");
 * console.log(`Last run status code: ${history[0]?.httpStatus}`);
 * ```
 */
export async function getCronJobHistory(id: string): Promise<{ history: HistoryItem[]; predictions: number[] }> {
    const response = await fetch(`${base_url}/jobs/${id}/history`, {
        method: "GET",
        headers
    });
    return handleResponse<{ history: HistoryItem[]; predictions: number[] }>(response);
}

/**
 * Retrieves detailed logs (including response body and headers) for a specific history item of a cron job.
 * 
 * @param id - The ID of the cron job
 * @param identifier - The history item identifier (e.g. "12345-22-11-4946")
 * 
 * @example
 * ```typescript
 * const details = await getCronJobHistoryItem("12345", "12345-22-11-4946");
 * console.log(`Response body: ${details.body}`);
 * ```
 */
export async function getCronJobHistoryItem(id: string, identifier: string): Promise<HistoryItem> {
    const response = await fetch(`${base_url}/jobs/${id}/history/${identifier}`, {
        method: "GET",
        headers
    });
    const data = await handleResponse<{ jobHistoryDetails: HistoryItem }>(response);
    return data.jobHistoryDetails;
}

/**
 * Lists all folders present in the account.
 * 
 * @example
 * ```typescript
 * const folders = await listFolders();
 * console.log(`Found ${folders.length} folders`);
 * ```
 */
export async function listFolders(): Promise<Folder[]> {
    const response = await fetch(`${base_url}/folders`, {
        method: "GET",
        headers
    });
    const data = await handleResponse<{ folders: Folder[] }>(response);
    return data.folders;
}

/**
 * Retrieves detailed information of a folder by its ID.
 * 
 * @param id - The ID of the folder
 * 
 * @example
 * ```typescript
 * const folder = await getFolderByID("9876");
 * console.log(`Folder title: ${folder.title}`);
 * ```
 */
export async function getFolderByID(id: string): Promise<Folder> {
    const response = await fetch(`${base_url}/folders/${id}`, {
        method: "GET",
        headers
    });
    const data = await handleResponse<{ folderDetails: Folder }>(response);
    return data.folderDetails;
}

/**
 * Creates a new folder to organize cron jobs.
 * 
 * @param title - The unique title of the folder (max 128 characters)
 * @returns The ID of the newly created folder
 * 
 * @example
 * ```typescript
 * const folderId = await createFolder("Backups");
 * ```
 */
export async function createFolder(title: string): Promise<number> {
    const response = await fetch(`${base_url}/folders`, {
        method: "PUT",
        headers,
        body: JSON.stringify({ folder: { title } })
    });
    const data = await handleResponse<{ folderId: number }>(response);
    return data.folderId;
}

/**
 * Updates the title of an existing folder.
 * 
 * @param id - The ID of the folder to update
 * @param title - The new title for the folder
 * 
 * @example
 * ```typescript
 * await updateFolder("9876", "Daily Backups");
 * ```
 */
export async function updateFolder(id: string, title: string): Promise<void> {
    const response = await fetch(`${base_url}/folders/${id}`, {
        method: "PATCH",
        headers,
        body: JSON.stringify({ folder: { title } })
    });
    await handleResponse<Record<string, never>>(response);
}

/**
 * Deletes a folder by its ID. Cron jobs inside the folder are moved to the root folder (id: 0) first.
 * 
 * @param id - The ID of the folder to delete
 * 
 * @example
 * ```typescript
 * await deleteFolder("9876");
 * ```
 */
export async function deleteFolder(id: string): Promise<void> {
    const response = await fetch(`${base_url}/folders/${id}`, {
        method: "DELETE",
        headers
    });
    await handleResponse<Record<string, never>>(response);
}

/**
 * Higher-level helper to automatically create or update a user's report cron job on cron-job.org.
 * Saves the cronJobId in the database settings.
 */
export async function setupOrUpdateUserCron(
    userId: string,
    reportHour: number,
    reportMinute: number,
    timezone: string = "Asia/Kolkata"
): Promise<number | null> {
    try {
        const serverBaseUrl = appConfig.serverBaseUrl;
        if (!serverBaseUrl) {
            console.warn("SERVER_BASE_URL is not set in environment. Skipping cron job configuration.");
            return null;
        }

        // Retrieve the Briefly Reports folder ID
        const folderConstant = await prisma.appConstants.findUnique({
            where: { key: "BRIEFLY_REPORTS_FOLDER_ID" }
        });
        const folderId = folderConstant ? Number(folderConstant.value) : 0;

        const settings = await prisma.settings.findUnique({
            where: { userId }
        });

        const triggerUrl = `${serverBaseUrl}/api/v1/users/${userId}/trigger-report`;
        const schedule = {
            timezone,
            hours: [reportHour],
            minutes: [reportMinute],
            mdays: [-1],
            months: [-1],
            wdays: [-1]
        };

        if (settings?.cronJobId) {
            console.log(`Updating existing cron job ${settings.cronJobId} for user ${userId}...`);
            await updateCronJob(String(settings.cronJobId), {
                enabled: true,
                schedule
            });
            return settings.cronJobId;
        } else {
            console.log(`Creating new cron job for user ${userId}...`);
            const jobId = await createCronJob({
                title: `Briefly Daily Report - ${userId}`,
                url: triggerUrl,
                enabled: true,
                folderId,
                requestMethod: 1, // RequestMethod.POST
                schedule
            });

            await prisma.settings.update({
                where: { userId },
                data: { cronJobId: jobId }
            });

            return jobId;
        }
    } catch (err: any) {
        console.error(`Failed to setup/update cron job for user ${userId}:`, err.message || err);
        return null;
    }
}