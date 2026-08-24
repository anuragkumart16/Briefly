import { NextResponse } from 'next/server';
import { getServerSession } from 'next-auth';
import { getToken } from 'next-auth/jwt';
import { authOptions } from '../auth/[...nextauth]/route';

export async function GET(request: Request) {
  const token = await getToken({ req: request as any });
  const session = await getServerSession(authOptions);

  if (!session || !token?.accessToken) {
    return NextResponse.json({ error: 'Unauthorized. Please sign in.' }, { status: 401 });
  }

  const accessToken = token.accessToken as string;
  const userEmail = session.user?.email;
  const baseUrl = process.env.BRIEFLY_SERVICE_BASE_URL || 'https://briefly-nine-tan.vercel.app';
  const groqApiKey = process.env.GROQ_API_KEY;

  // Calculate timeMin / timeMax for today in user's timezone (defaulting to Asia/Kolkata or local)
  const now = new Date();
  const startOfDay = new Date(now.getFullYear(), now.getMonth(), now.getDate(), 0, 0, 0);
  const endOfDay = new Date(now.getFullYear(), now.getMonth(), now.getDate(), 23, 59, 59, 999);

  const timeMin = startOfDay.toISOString();
  const timeMax = endOfDay.toISOString();

  let userFloats: string[] = [];
  let userObjectId: string | null = null;

  // 1. Try to lookup user & fetch floats from briefly_service
  try {
    if (baseUrl && userEmail) {
      const userRes = await fetch(`${baseUrl}/api/v1/users/by-email/${encodeURIComponent(userEmail)}`, { method: 'GET' }).catch(() => null);
      if (userRes && userRes.ok) {
        const userData = await userRes.json();
        if (userData?.data?.id) {
          userObjectId = userData.data.id;
          // Fetch floats for this user from briefly_service
          const floatsRes = await fetch(`${baseUrl}/api/v1/users/${userObjectId}/floats`, { method: 'GET' }).catch(() => null);
          if (floatsRes && floatsRes.ok) {
            const floatsData = await floatsRes.json();
            if (Array.isArray(floatsData?.data)) {
              userFloats = floatsData.data.filter((f: any) => f.isActive !== false).map((f: any) => f.text);
            }
          }
        }
      }
    }
  } catch (serviceErr) {
    console.warn('briefly_service lookup warning:', serviceErr);
  }

  // 2. Fetch live data directly using user's Google accessToken
  try {
    const [emails, calendarEvents, tasks] = await Promise.all([
      // Fetch Gmail unread emails
      fetchGmailEmails(accessToken),
      // Fetch Google Calendar events
      fetchCalendarEvents(accessToken, timeMin, timeMax),
      // Fetch Google Tasks
      fetchGoogleTasks(accessToken),
    ]);

    // 3. Compile AI summary using Groq API if key is present
    let aiReport: any = null;
    if (groqApiKey) {
      aiReport = await generateGroqSummary({
        groqApiKey,
        userEmail: userEmail || '',
        emails,
        calendarEvents,
        tasks,
        userFloats,
      });
    }

    // Pick a Float from the user's active floats if available
    let chosenWisdom = aiReport?.wisdom;
    if (userFloats.length > 0) {
      const randomIndex = Math.floor(Math.random() * userFloats.length);
      chosenWisdom = userFloats[randomIndex];
    }

    const reportData = {
      summary: aiReport?.summary || `You have ${emails.length} unread emails, ${calendarEvents.length} calendar events, and ${tasks.length} pending tasks today.`,
      wisdom: chosenWisdom || aiReport?.wisdom || "Focus is a matter of deciding what things you're not going to do. — John Carmack",
      emails: aiReport?.emails || emails.map(e => ({
        id: e.id,
        threadId: e.threadId,
        subject: e.subject,
        from: e.from,
        priority: 'medium',
        crux: e.snippet,
        whySent: 'Direct communication',
        summary: e.snippet,
        link: `https://mail.google.com/mail/u/0/#inbox/${e.threadId}`
      })),
      calendar: aiReport?.calendar || calendarEvents.map((c: any) => ({
        title: c.summary,
        time: c.start ? new Date(c.start).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }) : 'All day',
        location: c.location || 'Online',
        attendees: c.attendees ? c.attendees.join(', ') : 'Only you',
        summary: c.description || 'Calendar Event'
      })),
      tasks: aiReport?.tasks || tasks.map((t: any) => ({
        title: t.title,
        status: t.status,
        deadline: t.due ? new Date(t.due).toLocaleDateString() : 'No deadline',
        details: t.notes || ''
      })),
      rawCounts: {
        emailsCount: emails.length,
        eventsCount: calendarEvents.length,
        tasksCount: tasks.length
      }
    };

    return NextResponse.json({
      status: 200,
      message: 'Daily report compiled successfully',
      data: reportData
    });
  } catch (err: any) {
    console.error('Error compiling daily report:', err);
    return NextResponse.json({
      error: 'Failed to compile report',
      details: err.message || String(err)
    }, { status: 500 });
  }
}

async function fetchGmailEmails(accessToken: string) {
  try {
    const query = 'is:unread -category:promotions -category:social';
    const res = await fetch(`https://gmail.googleapis.com/gmail/v1/users/me/messages?q=${encodeURIComponent(query)}&maxResults=8`, {
      headers: { Authorization: `Bearer ${accessToken}` },
    });

    if (!res.ok) return [];
    const data = await res.json();
    if (!data.messages) return [];

    const messages = await Promise.all(
      data.messages.slice(0, 5).map(async (msg: any) => {
        const detailRes = await fetch(`https://gmail.googleapis.com/gmail/v1/users/me/messages/${msg.id}?format=full`, {
          headers: { Authorization: `Bearer ${accessToken}` },
        });
        if (!detailRes.ok) return null;
        const details = await detailRes.json();
        const headers = details.payload?.headers || [];
        const subject = headers.find((h: any) => h.name.toLowerCase() === 'subject')?.value || 'No Subject';
        const from = headers.find((h: any) => h.name.toLowerCase() === 'from')?.value || 'Unknown';
        const date = headers.find((h: any) => h.name.toLowerCase() === 'date')?.value || '';

        return {
          id: details.id,
          threadId: details.threadId,
          subject,
          from,
          date,
          snippet: details.snippet || '',
        };
      })
    );

    return messages.filter(Boolean);
  } catch (e) {
    console.error('Error fetching Gmail:', e);
    return [];
  }
}

async function fetchCalendarEvents(accessToken: string, timeMin: string, timeMax: string) {
  try {
    const url = `https://www.googleapis.com/calendar/v3/calendars/primary/events?timeMin=${encodeURIComponent(timeMin)}&timeMax=${encodeURIComponent(timeMax)}&singleEvents=true&orderBy=startTime`;
    const res = await fetch(url, {
      headers: { Authorization: `Bearer ${accessToken}` },
    });

    if (!res.ok) return [];
    const data = await res.json();
    if (!data.items) return [];

    return data.items.map((event: any) => ({
      summary: event.summary || 'No Title',
      description: event.description || '',
      start: event.start?.dateTime || event.start?.date || '',
      end: event.end?.dateTime || event.end?.date || '',
      location: event.location || '',
      attendees: (event.attendees || []).map((a: any) => a.displayName || a.email),
    }));
  } catch (e) {
    console.error('Error fetching Calendar:', e);
    return [];
  }
}

async function fetchGoogleTasks(accessToken: string) {
  try {
    const listRes = await fetch('https://tasks.googleapis.com/tasks/v1/users/@me/lists', {
      headers: { Authorization: `Bearer ${accessToken}` },
    });

    if (!listRes.ok) return [];
    const listData = await listRes.json();
    if (!listData.items || listData.items.length === 0) return [];

    const listId = listData.items[0].id;
    const tasksRes = await fetch(`https://tasks.googleapis.com/tasks/v1/lists/${listId}/tasks?showCompleted=false`, {
      headers: { Authorization: `Bearer ${accessToken}` },
    });

    if (!tasksRes.ok) return [];
    const tasksData = await tasksRes.json();
    if (!tasksData.items) return [];

    return tasksData.items.map((task: any) => ({
      id: task.id,
      title: task.title || 'Untitled Task',
      notes: task.notes || '',
      due: task.due || '',
      status: task.status || 'needsAction',
    }));
  } catch (e) {
    console.error('Error fetching Tasks:', e);
    return [];
  }
}

async function generateGroqSummary({ groqApiKey, userEmail, emails, calendarEvents, tasks, userFloats }: any) {
  try {
    const prompt = `You are Briefly, a personal AI executive assistant. Generate a focused daily report for ${userEmail}.
Data:
- User's Floats (Stored wisdom reminders): ${JSON.stringify(userFloats || [])}
- Unread emails: ${JSON.stringify(emails)}
- Calendar events: ${JSON.stringify(calendarEvents)}
- Tasks: ${JSON.stringify(tasks)}

Return ONLY valid JSON with no markdown formatting or codeblocks:
{
  "summary": "A friendly 2-3 sentence overview of the day.",
  "wisdom": "An actionable motivational quote synthesized from their Floats or general wisdom.",
  "emails": [ { "id": "id", "threadId": "threadId", "subject": "Subject", "from": "Sender", "priority": "high|medium", "crux": "Main point", "summary": "Short summary", "link": "https://mail.google.com/mail/u/0/#inbox/{threadId}" } ],
  "calendar": [ { "title": "Title", "time": "Time", "location": "Location", "attendees": "Attendees", "summary": "Short summary" } ],
  "tasks": [ { "title": "Title", "status": "needsAction", "deadline": "Deadline", "details": "Notes" } ]
}`;

    const res = await fetch('https://api.groq.com/openai/v1/chat/completions', {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${groqApiKey}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        model: 'llama-3.3-70b-versatile',
        messages: [{ role: 'user', content: prompt }],
        response_format: { type: 'json_object' },
        temperature: 0.3,
      }),
    });

    if (!res.ok) return null;
    const data = await res.json();
    const content = data.choices?.[0]?.message?.content;
    if (!content) return null;
    return JSON.parse(content);
  } catch (e) {
    console.error('Error generating Groq AI summary:', e);
    return null;
  }
}
