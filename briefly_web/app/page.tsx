'use client';

import React, { useState } from 'react';

// Sample wisdom items for the Floats interactive preview
const WISDOM_ITEMS = [
  {
    quote: "The only limit to our realization of tomorrow will be our doubts of today.",
    author: "Franklin D. Roosevelt"
  },
  {
    quote: "The happiness of your life depends upon the quality of your thoughts.",
    author: "Marcus Aurelius"
  },
  {
    quote: "Focus is a matter of deciding what things you're not going to do.",
    author: "John Carmack"
  },
  {
    quote: "We suffer more often in imagination than in reality.",
    author: "Seneca"
  },
  {
    quote: "It does not matter how slowly you go as long as you do not stop.",
    author: "Confucius"
  }
];

export default function Home() {
  const [activeTab, setActiveTab] = useState<'report' | 'floats' | 'settings'>('report');
  const [wisdomIndex, setWisdomIndex] = useState(0);
  const [scheduledTime, setScheduledTime] = useState('07:30 AM');

  // App config toggles for settings preview
  const [includeEmails, setIncludeEmails] = useState(true);
  const [includeCalendar, setIncludeCalendar] = useState(true);
  const [includeTasks, setIncludeTasks] = useState(true);
  const [includeFloats, setIncludeFloats] = useState(true);

  const nextWisdom = () => {
    setWisdomIndex((prev) => (prev + 1) % WISDOM_ITEMS.length);
  };

  const downloadUrl = "https://github.com/anuragkumart16/Briefly/releases/download/PROD/app-release.apk";
  const repoUrl = "https://github.com/anuragkumart16/Briefly";

  return (
    <div className="min-h-screen bg-white text-zinc-900 font-sans antialiased selection:bg-brand/10 selection:text-brand flex flex-col">
      {/* Background Grid Pattern */}
      <div className="absolute inset-0 bg-grid -z-10 opacity-70 pointer-events-none" />

      {/* Navigation */}
      <header className="sticky top-0 z-50 bg-white/80 backdrop-blur-md border-b border-zinc-100 px-4 py-4 sm:px-8">
        <div className="max-w-6xl mx-auto flex items-center justify-between">
          <a href="#" className="flex items-center gap-2">
            <span className="font-display text-2xl font-bold tracking-tight text-brand">
              Briefly
            </span>
          </a>
          <nav className="hidden md:flex items-center gap-8 text-sm font-medium text-zinc-600">
            <a href="#features" className="hover:text-brand transition-colors">Features</a>
            <a href="#how-it-works" className="hover:text-brand transition-colors">How it works</a>
            <a href="#download" className="hover:text-brand transition-colors">Download</a>
            <a href={repoUrl} target="_blank" rel="noopener noreferrer" className="hover:text-brand transition-colors">Source Code</a>
          </nav>
          <div className="flex items-center gap-3">
            <a
              href={downloadUrl}
              className="px-4 py-2 text-xs sm:text-sm font-semibold text-white bg-brand hover:bg-brand-hover rounded-xl transition-all shadow-sm premium-glow flex items-center gap-1.5"
            >
              <span>Download APK</span>
              <svg className="w-3.5 h-3.5" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2.5}>
                <path strokeLinecap="round" strokeLinejoin="round" d="M4 16v1a3 3 0 003 3h10a3 3 0 003-3v-1m-4-4l-4 4m0 0l-4-4m4 4V4" />
              </svg>
            </a>
          </div>
        </div>
      </header>

      {/* Hero Section */}
      <section className="relative pt-12 pb-20 px-4 sm:px-8 max-w-6xl mx-auto flex-1 flex flex-col justify-center">
        <div className="grid grid-cols-1 lg:grid-cols-12 gap-12 lg:gap-16 items-center">
          
          {/* Left Column: Copy */}
          <div className="lg:col-span-7 flex flex-col items-start text-left">
            {/* Version Badge */}
            <div className="inline-flex items-center gap-2 px-3 py-1 bg-brand-light border border-brand/20 rounded-full text-xs font-semibold text-brand mb-6 animate-pulse">
              <span className="w-1.5 h-1.5 rounded-full bg-brand" />
              <span>v1.0.1 PROD Release is Live</span>
            </div>

            <h1 className="font-display text-4xl sm:text-5xl lg:text-6xl font-bold tracking-tight text-zinc-950 leading-[1.1] mb-6">
              News about you,<br />
              packed in <span className="text-brand">daily reports</span>.
            </h1>

            <p className="text-zinc-600 text-base sm:text-lg md:text-xl font-normal leading-relaxed max-w-xl mb-8">
              Notifications distract you all day. Briefly consolidates your emails, calendars, and todo list items into a single, clean markdown digest delivered exactly when you want it. No cloud servers, no trackers.
            </p>

            <div className="flex flex-col sm:flex-row gap-4 w-full sm:w-auto mb-10">
              <a
                href={downloadUrl}
                className="px-8 py-4 bg-brand hover:bg-brand-hover text-white font-bold rounded-2xl text-center transition-all shadow-md premium-glow flex items-center justify-center gap-2 group"
              >
                <span>Download for Android</span>
                <svg className="w-5 h-5 group-hover:translate-y-0.5 transition-transform" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2.5}>
                  <path strokeLinecap="round" strokeLinejoin="round" d="M4 16v1a3 3 0 003 3h10a3 3 0 003-3v-1m-4-4l-4 4m0 0l-4-4m4 4V4" />
                </svg>
              </a>
              <a
                href={repoUrl}
                target="_blank"
                rel="noopener noreferrer"
                className="px-8 py-4 border border-zinc-200 hover:border-zinc-300 bg-white hover:bg-zinc-50 font-bold rounded-2xl text-center text-zinc-700 transition-all flex items-center justify-center gap-2"
              >
                <svg className="w-5 h-5 text-zinc-800" viewBox="0 0 24 24" fill="currentColor">
                  <path fillRule="evenodd" clipRule="evenodd" d="M12 2C6.477 2 2 6.477 2 12c0 4.42 2.865 8.166 6.839 9.489.5.092.682-.217.682-.482 0-.237-.008-.866-.013-1.7-2.782.603-3.369-1.34-3.369-1.34-.454-1.156-1.11-1.462-1.11-1.462-.908-.62.069-.608.069-.608 1.003.07 1.531 1.03 1.531 1.03.892 1.529 2.341 1.087 2.91.831.092-.646.35-1.086.636-1.336-2.22-.253-4.555-1.11-4.555-4.943 0-1.091.39-1.984 1.029-2.683-.103-.253-.446-1.27.098-2.647 0 0 .84-.269 2.75 1.025A9.564 9.564 0 0112 6.844c.85.004 1.705.115 2.504.337 1.909-1.294 2.747-1.025 2.747-1.025.546 1.377.203 2.394.1 2.647.64.699 1.028 1.592 1.028 2.683 0 3.842-2.339 4.687-4.566 4.935.359.309.678.919.678 1.852 0 1.336-.012 2.415-.012 2.743 0 .267.18.577.688.479C19.138 20.161 22 16.418 22 12c0-5.523-4.477-10-10-10z" />
                </svg>
                <span>GitHub Source</span>
              </a>
            </div>

            {/* Quick specifications */}
            <div className="flex flex-wrap items-center gap-x-6 gap-y-2 text-xs text-zinc-500 border-t border-zinc-100 pt-6 w-full">
              <div><strong>Format:</strong> APK (Android)</div>
              <div className="hidden sm:block text-zinc-300">|</div>
              <div><strong>Size:</strong> 52.4 MB</div>
              <div className="hidden sm:block text-zinc-300">|</div>
              <div><strong>Requirements:</strong> Android 8.0+</div>
              <div className="hidden sm:block text-zinc-300">|</div>
              <div><strong>Status:</strong> Safe & Local</div>
            </div>
          </div>

          {/* Right Column: Interactive Phone Mockup */}
          <div className="lg:col-span-5 flex flex-col items-center">
            
            {/* Tab Toggles for device screen */}
            <div className="flex bg-zinc-100/80 backdrop-blur p-1 rounded-xl mb-6 gap-1 w-full max-w-[320px] sm:max-w-[340px] text-xs font-semibold text-zinc-600">
              <button
                onClick={() => setActiveTab('report')}
                className={`flex-1 py-2 text-center rounded-lg transition-all ${activeTab === 'report' ? 'bg-white text-brand shadow-sm' : 'hover:text-zinc-950'}`}
              >
                Daily Report
              </button>
              <button
                onClick={() => setActiveTab('floats')}
                className={`flex-1 py-2 text-center rounded-lg transition-all ${activeTab === 'floats' ? 'bg-white text-brand shadow-sm' : 'hover:text-zinc-950'}`}
              >
                Floats
              </button>
              <button
                onClick={() => setActiveTab('settings')}
                className={`flex-1 py-2 text-center rounded-lg transition-all ${activeTab === 'settings' ? 'bg-white text-brand shadow-sm' : 'hover:text-zinc-950'}`}
              >
                App Settings
              </button>
            </div>

            {/* Phone Container */}
            <div className="relative w-[280px] h-[560px] sm:w-[320px] sm:h-[640px] bg-zinc-950 rounded-[48px] p-3 shadow-2xl border-4 border-zinc-800 premium-glow transition-all flex flex-col justify-between">
              
              {/* iPhone style top notch */}
              <div className="iphone-notch" />

              {/* Status bar */}
              <div className="flex justify-between items-center px-6 pt-2 text-[10px] font-bold text-zinc-400 z-20">
                <span>09:41</span>
                <div className="flex items-center gap-1.5">
                  {/* Signal Icon */}
                  <svg className="w-3.5 h-3.5 fill-current" viewBox="0 0 24 24"><path d="M12 3c-1.2 0-2.4.4-3.4 1.1L3 8.6c-.6.4-.6 1.3 0 1.7l1.1.8c.4.3 1 .2 1.3-.2l4.2-3.2c1.4-1.1 3.4-1.1 4.8 0l4.2 3.2c.4.4.9.4 1.3.2l1.1-.8c.6-.4.6-1.3 0-1.7l-5.6-4.5C14.4 3.4 13.2 3 12 3zm0 4.5c-.7 0-1.4.2-2 .6l-4.5 3.6c-.4.3-.4.9 0 1.2l.9.7c.3.2.7.2 1-.1l3.5-2.8c.6-.5 1.5-.5 2.1 0l3.5 2.8c.3.3.7.3 1 .1l.9-.7c.4-.3.4-.9 0-1.2l-4.5-3.6c-.6-.4-1.3-.6-2-.6zm0 4.5c-.2 0-.5.1-.7.2l-3.3 2.6c-.2.2-.2.5 0 .7l.7.6c.2.2.5.2.7 0l2.5-2c.1-.1.2-.1.3-.1.1 0 .2 0 .3.1l2.5 2c.2.2.5.2.7 0l.7-.6c.2-.2.2-.5 0-.7l-3.3-2.6c-.2-.1-.5-.2-.7-.2z"/></svg>
                  {/* Battery Icon */}
                  <div className="w-5 h-2.5 border border-zinc-500 rounded-sm p-0.5 flex items-center">
                    <div className="bg-zinc-400 h-full w-[80%] rounded-[1px]" />
                  </div>
                </div>
              </div>

              {/* Inner screen content */}
              <div className="flex-1 mt-3 mb-2 bg-zinc-50 rounded-[36px] overflow-hidden border border-zinc-200 flex flex-col relative">
                
                {/* 1. Daily Report Screen View */}
                {activeTab === 'report' && (
                  <div className="flex-1 flex flex-col px-4 pt-4 pb-6 overflow-y-auto text-xs text-zinc-800">
                    <div className="flex justify-between items-center mb-4 border-b border-zinc-200/60 pb-2">
                      <span className="font-display text-base font-bold text-brand">Briefly Report</span>
                      <span className="px-2 py-0.5 bg-zinc-200/60 text-zinc-600 rounded text-[9px] font-semibold">Today • {scheduledTime}</span>
                    </div>

                    <div className="space-y-4">
                      {/* Section: Overview */}
                      <div>
                        <h3 className="font-semibold text-zinc-950 mb-1.5 flex items-center gap-1">
                          <span>⚡</span>
                          <span>Today's Overview</span>
                        </h3>
                        <p className="text-zinc-600 leading-relaxed bg-white border border-zinc-100 p-2.5 rounded-xl shadow-xs">
                          You have <strong>{((includeEmails ? 2 : 0) + (includeCalendar ? 2 : 0) + (includeTasks ? 2 : 0))} items</strong> today requiring attention.
                          {includeFloats && (
                            <span className="block mt-1.5 pt-1.5 border-t border-zinc-100 text-[10px] text-zinc-500 italic">
                              💡 Wisdom: "{WISDOM_ITEMS[wisdomIndex].quote}"
                            </span>
                          )}
                        </p>
                      </div>

                      {/* Section: Email Digest */}
                      {includeEmails && (
                        <div>
                          <h3 className="font-semibold text-zinc-950 mb-1.5 flex items-center gap-1">
                            <span>📧</span>
                            <span>Email Summaries</span>
                          </h3>
                          <div className="bg-white border border-zinc-100 rounded-xl divide-y divide-zinc-100 shadow-xs overflow-hidden">
                            <div className="p-2.5">
                              <div className="flex justify-between font-medium text-zinc-900 mb-0.5">
                                <span>Sarah Jenkins</span>
                                <span className="text-[10px] text-brand">Feedback</span>
                              </div>
                              <p className="text-zinc-500 text-[11px] leading-snug">Needs slide review for client presentation by 2:00 PM.</p>
                            </div>
                            <div className="p-2.5">
                              <div className="flex justify-between font-medium text-zinc-900 mb-0.5">
                                <span>Flight Alert</span>
                                <span className="text-[10px] text-zinc-400">Logistics</span>
                              </div>
                              <p className="text-zinc-500 text-[11px] leading-snug">Indigo flight 6E-2304 is on-time. Terminal 2 at 6:15 PM.</p>
                            </div>
                          </div>
                        </div>
                      )}

                      {/* Section: Calendar */}
                      {includeCalendar && (
                        <div>
                          <h3 className="font-semibold text-zinc-950 mb-1.5 flex items-center gap-1">
                            <span>📅</span>
                            <span>Calendar Schedule</span>
                          </h3>
                          <div className="space-y-1.5">
                            <div className="flex items-center gap-2 bg-brand/5 border border-brand/10 p-2 rounded-xl">
                              <div className="w-1.5 h-1.5 rounded-full bg-brand" />
                              <div className="flex-1">
                                <div className="font-medium text-zinc-900 text-[11px]">Sprint Planning Session</div>
                                <div className="text-[10px] text-zinc-500">10:00 AM - 11:30 AM</div>
                              </div>
                            </div>
                            <div className="flex items-center gap-2 bg-zinc-100/80 border border-zinc-200/40 p-2 rounded-xl">
                              <div className="w-1.5 h-1.5 rounded-full bg-zinc-400" />
                              <div className="flex-1">
                                <div className="font-medium text-zinc-900 text-[11px]">Client Demo: Briefly Web</div>
                                <div className="text-[10px] text-zinc-500">02:00 PM - 02:45 PM</div>
                              </div>
                            </div>
                          </div>
                        </div>
                      )}

                      {/* Section: Todos */}
                      {includeTasks && (
                        <div>
                          <h3 className="font-semibold text-zinc-950 mb-1.5 flex items-center gap-1">
                            <span>✅</span>
                            <span>Todo List</span>
                          </h3>
                          <div className="bg-white border border-zinc-100 rounded-xl p-2.5 shadow-xs space-y-2">
                            <div className="flex items-center gap-2">
                              <input type="checkbox" checked={false} readOnly className="rounded border-zinc-300 text-brand focus:ring-brand" />
                              <span className="text-[11px] text-zinc-700">Send updated presentation deck to client</span>
                            </div>
                            <div className="flex items-center gap-2">
                              <input type="checkbox" checked={false} readOnly className="rounded border-zinc-300 text-brand focus:ring-brand" />
                              <span className="text-[11px] text-zinc-700">Write summary changelog for release</span>
                            </div>
                          </div>
                        </div>
                      )}
                    </div>
                  </div>
                )}

                {/* 2. Floats Screen View */}
                {activeTab === 'floats' && (
                  <div className="flex-1 flex flex-col justify-between p-4 bg-zinc-900 text-white select-none">
                    {/* Header */}
                    <div className="flex justify-between items-center border-b border-white/10 pb-2">
                      <span className="font-display text-sm font-bold text-brand">Floats</span>
                      <span className="text-[9px] text-zinc-400 font-medium">WISDOM FEED</span>
                    </div>

                    {/* Wisdom Bubble Display */}
                    <div className="flex-1 flex flex-col justify-center items-center py-6">
                      <div className="w-10 h-10 rounded-2xl bg-brand/15 border border-brand/35 flex items-center justify-center text-brand mb-4 premium-glow">
                        💡
                      </div>
                      <blockquote className="text-center px-2 space-y-3">
                        <p className="text-zinc-200 text-sm font-medium leading-relaxed italic">
                          "{WISDOM_ITEMS[wisdomIndex].quote}"
                        </p>
                        <cite className="block text-brand text-[10px] tracking-wider uppercase font-bold not-italic">
                          — {WISDOM_ITEMS[wisdomIndex].author}
                        </cite>
                      </blockquote>
                    </div>

                    {/* Next Float Interactive Button */}
                    <div className="space-y-3">
                      <button
                        onClick={nextWisdom}
                        className="w-full py-2.5 bg-brand hover:bg-brand-hover text-white text-xs font-semibold rounded-xl transition-all flex items-center justify-center gap-1 cursor-pointer"
                      >
                        <span>Next Float</span>
                        <svg className="w-3.5 h-3.5" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2.5}>
                          <path strokeLinecap="round" strokeLinejoin="round" d="M9 5l7 7-7 7" />
                        </svg>
                      </button>
                      <p className="text-center text-[9px] text-zinc-500">
                        Floats trigger custom scheduled alarm push notifications every N hours.
                      </p>
                    </div>
                  </div>
                )}

                {/* 3. Settings Screen View */}
                {activeTab === 'settings' && (
                  <div className="flex-1 flex flex-col px-4 pt-4 pb-6 overflow-y-auto text-xs text-zinc-800">
                    <div className="flex justify-between items-center mb-4 border-b border-zinc-200/60 pb-2">
                      <span className="font-display text-base font-bold text-brand">Briefly Setup</span>
                      <span className="text-[10px] text-zinc-500 font-semibold">Config</span>
                    </div>

                    <div className="space-y-4">
                      {/* Feeds Switch Group */}
                      <div>
                        <h4 className="text-[10px] font-bold text-zinc-400 tracking-wider uppercase mb-2">Connected Feeds</h4>
                        <div className="bg-white border border-zinc-100 rounded-xl shadow-xs divide-y divide-zinc-50">
                          {/* Feed 1: Gmail Emails */}
                          <div className="flex items-center justify-between p-3">
                            <div className="flex items-center gap-2">
                              <span className="w-2.5 h-2.5 rounded-full bg-red-500" />
                              <span className="font-medium">Add Emails (Gmail)</span>
                            </div>
                            <button
                              onClick={() => setIncludeEmails(!includeEmails)}
                              className={`w-9 h-5 rounded-full p-0.5 transition-all cursor-pointer ${includeEmails ? 'bg-brand flex justify-end' : 'bg-zinc-200 flex justify-start'}`}
                            >
                              <span className="w-4 h-4 rounded-full bg-white shadow-sm" />
                            </button>
                          </div>
                          {/* Feed 2: Google Calendar */}
                          <div className="flex items-center justify-between p-3">
                            <div className="flex items-center gap-2">
                              <span className="w-2.5 h-2.5 rounded-full bg-blue-500" />
                              <span className="font-medium">Add Calendar</span>
                            </div>
                            <button
                              onClick={() => setIncludeCalendar(!includeCalendar)}
                              className={`w-9 h-5 rounded-full p-0.5 transition-all cursor-pointer ${includeCalendar ? 'bg-brand flex justify-end' : 'bg-zinc-200 flex justify-start'}`}
                            >
                              <span className="w-4 h-4 rounded-full bg-white shadow-sm" />
                            </button>
                          </div>
                          {/* Feed 3: Google Tasks */}
                          <div className="flex items-center justify-between p-3">
                            <div className="flex items-center gap-2">
                              <span className="w-2.5 h-2.5 rounded-full bg-amber-500" />
                              <span className="font-medium">Add Tasks</span>
                            </div>
                            <button
                              onClick={() => setIncludeTasks(!includeTasks)}
                              className={`w-9 h-5 rounded-full p-0.5 transition-all cursor-pointer ${includeTasks ? 'bg-brand flex justify-end' : 'bg-zinc-200 flex justify-start'}`}
                            >
                              <span className="w-4 h-4 rounded-full bg-white shadow-sm" />
                            </button>
                          </div>
                          {/* Feed 4: Floats Wisdom */}
                          <div className="flex items-center justify-between p-3">
                            <div className="flex items-center gap-2">
                              <span className="w-2.5 h-2.5 rounded-full bg-brand" />
                              <span className="font-medium">Add Floats</span>
                            </div>
                            <button
                              onClick={() => setIncludeFloats(!includeFloats)}
                              className={`w-9 h-5 rounded-full p-0.5 transition-all cursor-pointer ${includeFloats ? 'bg-brand flex justify-end' : 'bg-zinc-200 flex justify-start'}`}
                            >
                              <span className="w-4 h-4 rounded-full bg-white shadow-sm" />
                            </button>
                          </div>
                        </div>
                      </div>

                      {/* Delivery Scheduler */}
                      <div>
                        <h4 className="text-[10px] font-bold text-zinc-400 tracking-wider uppercase mb-2">Delivery Timing</h4>
                        <div className="bg-white border border-zinc-100 p-3 rounded-xl shadow-xs">
                          <label className="block text-[10px] text-zinc-500 mb-1">Morning report schedule</label>
                          <div className="flex gap-2">
                            <select
                              value={scheduledTime}
                              onChange={(e) => setScheduledTime(e.target.value)}
                              className="flex-1 border border-zinc-200 rounded-lg p-2 bg-zinc-50 font-semibold focus:outline-none focus:border-brand cursor-pointer"
                            >
                              <option value="07:00 AM">07:00 AM</option>
                              <option value="07:30 AM">07:30 AM</option>
                              <option value="08:00 AM">08:00 AM</option>
                              <option value="09:00 AM">09:00 AM</option>
                            </select>
                          </div>
                        </div>
                      </div>
                    </div>
                  </div>
                )}
                
                {/* Simulated Android Navigation Bar */}
                <div className="h-6 border-t border-zinc-200/60 bg-zinc-100 flex items-center justify-center gap-8 text-[11px] text-zinc-500">
                  <span>◀</span>
                  <span>●</span>
                  <span>■</span>
                </div>
              </div>
            </div>
          </div>

        </div>
      </section>

      {/* Trust & Features Section */}
      <section id="features" className="py-20 bg-zinc-50 border-y border-zinc-100 px-4 sm:px-8">
        <div className="max-w-6xl mx-auto">
          <div className="text-center max-w-2xl mx-auto mb-16">
            <h2 className="font-display text-3xl sm:text-4xl font-bold tracking-tight text-zinc-950 mb-4">
              Everything in one report. <span className="text-brand">Quietly.</span>
            </h2>
            <p className="text-zinc-600 text-sm sm:text-base leading-relaxed">
              We connect local account indexes on your device to parse, organize, and format incoming details so you can review them once and stay focused.
            </p>
          </div>

          <div className="grid grid-cols-1 md:grid-cols-3 gap-8">
            {/* Feature 1 */}
            <div className="bg-white p-8 rounded-3xl border border-zinc-100 shadow-xs flex flex-col items-start">
              <div className="w-12 h-12 rounded-2xl bg-brand-light flex items-center justify-center text-brand font-bold text-lg mb-6">
                📝
              </div>
              <h3 className="text-lg font-bold text-zinc-950 mb-3">Consolidated Reports</h3>
              <p className="text-zinc-600 text-sm leading-relaxed">
                Securely syncs Google Calendar, Gmail, and Google Tasks. Packages your updates using Groq-hosted AI into a clear markdown digest to save you from notification distraction.
              </p>
            </div>

            {/* Feature 2 */}
            <div className="bg-white p-8 rounded-3xl border border-zinc-100 shadow-xs flex flex-col items-start">
              <div className="w-12 h-12 rounded-2xl bg-brand-light flex items-center justify-center text-brand font-bold text-lg mb-6">
                ⚡
              </div>
              <h3 className="text-lg font-bold text-zinc-950 mb-3">Floats Wisdom</h3>
              <p className="text-zinc-600 text-sm leading-relaxed">
                Save ideas, key highlights, or quotes you tend to forget. Briefly schedules Android Alarm notifications periodically to keep wisdom fresh and applicable in daily work.
              </p>
            </div>

            {/* Feature 3 */}
            <div className="bg-white p-8 rounded-3xl border border-zinc-100 shadow-xs flex flex-col items-start">
              <div className="w-12 h-12 rounded-2xl bg-brand-light flex items-center justify-center text-brand font-bold text-lg mb-6">
                🔒
              </div>
              <h3 className="text-lg font-bold text-zinc-950 mb-3">Secure Flow</h3>
              <p className="text-zinc-600 text-sm leading-relaxed">
                Authenticate locally using official Google API OAuth client secrets. Your connection tokens are stored safely on-device and summaries are generated through a secure proxy.
              </p>
            </div>
          </div>
        </div>
      </section>

      {/* Integration Logos Section */}
      <section className="py-16 px-4 sm:px-8 max-w-6xl mx-auto text-center">
        <h3 className="text-[10px] font-bold text-zinc-400 tracking-wider uppercase mb-8">Supported Native Feeds</h3>
        <div className="flex flex-wrap justify-center items-center gap-8 sm:gap-16 opacity-75">
          <span className="font-semibold text-zinc-700 text-sm sm:text-base flex items-center gap-1.5">
            <span className="w-2.5 h-2.5 rounded-full bg-blue-500" /> Google Calendar
          </span>
          <span className="font-semibold text-zinc-700 text-sm sm:text-base flex items-center gap-1.5">
            <span className="w-2.5 h-2.5 rounded-full bg-red-500" /> Gmail Emails
          </span>
          <span className="font-semibold text-zinc-700 text-sm sm:text-base flex items-center gap-1.5">
            <span className="w-2.5 h-2.5 rounded-full bg-amber-500" /> Google Tasks
          </span>
          <span className="font-semibold text-zinc-700 text-sm sm:text-base flex items-center gap-1.5">
            <span className="w-2.5 h-2.5 rounded-full bg-brand" /> Floats Wisdom
          </span>
        </div>
      </section>

      {/* How it works Section */}
      <section id="how-it-works" className="py-20 bg-zinc-50 border-t border-zinc-100 px-4 sm:px-8">
        <div className="max-w-6xl mx-auto">
          <div className="text-center max-w-2xl mx-auto mb-16">
            <h2 className="font-display text-3xl sm:text-4xl font-bold tracking-tight text-zinc-950 mb-4">
              Get started in three steps
            </h2>
            <p className="text-zinc-600 text-sm sm:text-base leading-relaxed">
              No registration forms. No profile accounts. Directly set up on-device.
            </p>
          </div>

          <div className="grid grid-cols-1 md:grid-cols-3 gap-12 relative">
            <div className="flex flex-col items-start relative z-10">
              <div className="text-5xl font-display font-bold text-brand/20 mb-4">01</div>
              <h4 className="text-base font-bold text-zinc-950 mb-2">Download & Install APK</h4>
              <p className="text-zinc-600 text-sm leading-relaxed">
                Download the production Android APK directly from our public GitHub release tags page and run installation.
              </p>
            </div>

            <div className="flex flex-col items-start relative z-10">
              <div className="text-5xl font-display font-bold text-brand/20 mb-4">02</div>
              <h4 className="text-base font-bold text-zinc-950 mb-2">Configure Local Sources</h4>
              <p className="text-zinc-600 text-sm leading-relaxed">
                Select feed channels you want to connect and schedule your delivery times for daily reports and wisdom intervals.
              </p>
            </div>

            <div className="flex flex-col items-start relative z-10">
              <div className="text-5xl font-display font-bold text-brand/20 mb-4">03</div>
              <h4 className="text-base font-bold text-zinc-950 mb-2">Read Summaries & Focus</h4>
              <p className="text-zinc-600 text-sm leading-relaxed">
                Receive notifications only when you expect them. Review details once, ignore distraction popups, and focus on details.
              </p>
            </div>
          </div>
        </div>
      </section>

      {/* Download Box Section */}
      <section id="download" className="py-24 px-4 sm:px-8 max-w-4xl mx-auto text-center">
        <div className="bg-brand rounded-[32px] p-8 sm:p-12 text-white relative overflow-hidden premium-glow">
          {/* Subtle decoration dots pattern */}
          <div className="absolute inset-0 dot-pattern opacity-10 pointer-events-none" />
          
          <div className="relative z-10 max-w-xl mx-auto flex flex-col items-center">
            <span className="px-3 py-1 bg-white/15 rounded-full text-xs font-semibold tracking-wide uppercase mb-6">
              Production Release Build
            </span>
            <h2 className="font-display text-3xl sm:text-5xl font-bold tracking-tight leading-tight mb-4">
              Get Briefly for Android
            </h2>
            <p className="text-white/85 text-sm sm:text-base leading-relaxed mb-8">
              Download the secure offline distribution package (app-release.apk) directly from GitHub repository. Build release verified under Tag <strong>PROD</strong>.
            </p>

            <div className="flex flex-col sm:flex-row gap-4 w-full sm:w-auto justify-center mb-6">
              <a
                href={downloadUrl}
                className="px-8 py-4 bg-white hover:bg-zinc-100 text-brand font-bold rounded-2xl text-center shadow-md transition-all flex items-center justify-center gap-2 group"
              >
                <span>Download APK (52.4 MB)</span>
                <svg className="w-5 h-5 group-hover:translate-y-0.5 transition-transform" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2.5}>
                  <path strokeLinecap="round" strokeLinejoin="round" d="M4 16v1a3 3 0 003 3h10a3 3 0 003-3v-1m-4-4l-4 4m0 0l-4-4m4 4V4" />
                </svg>
              </a>
              <a
                href={repoUrl}
                target="_blank"
                rel="noopener noreferrer"
                className="px-8 py-4 bg-brand-hover hover:bg-brand-hover/90 border border-white/20 text-white font-bold rounded-2xl text-center transition-all flex items-center justify-center gap-2"
              >
                <span>View Release on GitHub</span>
              </a>
            </div>
            
            <p className="text-white/70 text-xs">
              Latest Production Release v1.0.1 • Requires Android 8.0 Oreo or higher.
            </p>
          </div>
        </div>
      </section>

      {/* Footer */}
      <footer className="bg-zinc-950 text-zinc-500 py-12 px-4 sm:px-8 border-t border-zinc-900 mt-auto">
        <div className="max-w-6xl mx-auto flex flex-col md:flex-row justify-between items-center gap-6">
          <div className="flex flex-col items-center md:items-start gap-2">
            <span className="font-display text-xl font-bold tracking-tight text-white">
              Briefly
            </span>
            <p className="text-xs text-zinc-600 text-center md:text-left">
              Secure daily reports & floats. Built for focus.
            </p>
          </div>
          <div className="flex flex-wrap justify-center gap-6 text-xs">
            <a href="#features" className="hover:text-white transition-colors">Features</a>
            <a href="#how-it-works" className="hover:text-white transition-colors">How It Works</a>
            <a href={repoUrl} target="_blank" rel="noopener noreferrer" className="hover:text-white transition-colors">GitHub Repository</a>
          </div>
          <div className="text-[10px] text-zinc-600">
            &copy; {new Date().getFullYear()} Briefly App. Open Source MIT License.
          </div>
        </div>
      </footer>
    </div>
  );
}
