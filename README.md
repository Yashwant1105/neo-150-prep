<div align="center">

# 🚀 Neo 150 Prep

### Your structured companion for mastering coding interviews.

A modern, cross-platform interview preparation app built around the **NeetCode 150**, combining structured problem tracking, progress analytics, AI coaching, mock interviews, gamification, cloud sync, and smart notifications.

<br />

<!-- Replace these with your actual links -->
<a href="https://neo-150-prep.web.app/">🌐 Live Web App</a>
&nbsp; • &nbsp;
<a href="https://github.com/Yashwant1105/mins-prep">📦 GitHub</a>
&nbsp; • &nbsp;
<a href="YOUR_APK_URL">📱 Download APK</a>

<br /><br />

![Flutter](https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white)
![Dart](https://img.shields.io/badge/Dart-0175C2?style=for-the-badge&logo=dart&logoColor=white)
![Supabase](https://img.shields.io/badge/Supabase-3ECF8E?style=for-the-badge&logo=supabase&logoColor=white)
![Firebase](https://img.shields.io/badge/Firebase-FFCA28?style=for-the-badge&logo=firebase&logoColor=black)
![Gemini](https://img.shields.io/badge/Gemini_AI-4285F4?style=for-the-badge&logo=google&logoColor=white)

<br />

> **Consistency beats cramming.**
>
> Neo 150 Prep helps you turn interview preparation into a structured, measurable, and motivating daily system.

</div>

---

# ✨ What is Neo 150 Prep?

Preparing for coding interviews can feel overwhelming.

You have hundreds of problems, dozens of topics, inconsistent practice habits, and no clear way to understand where you're improving.

**Neo 150 Prep solves that problem by turning interview preparation into a complete system.**

Track your problems, identify weak topics, build streaks, earn XP, unlock achievements, receive AI guidance, practice mock interviews, and stay consistent with smart reminders.

All centered around the **NeetCode 150**.

---

# 🎯 Features

## 🧩 Master the NeetCode 150

Explore a curated collection of **150 interview problems across 18 categories**.

- 🔍 Search by problem title
- 🏷 Filter by topic
- 🎚 Filter by difficulty
- ✅ Filter by completion status
- 🔄 Review queue filtering
- ↕️ Multiple sorting options
- 🔗 Direct problem links
- 📝 Personal notes
- 📅 Review scheduling

Every problem becomes part of your personalized preparation journey.

---

## 📅 Daily Prep

Neo 150 Prep helps remove the question:

> *"What should I solve today?"*

The app generates a daily preparation plan based on your progress.

Features include:

- Daily recommended problems
- Next incomplete problem
- Problems due for review
- Daily completion tracking
- Adjustable daily goals

Choose a daily goal of:

- 1 problem
- 2 problems
- 3 problems
- 5 problems

---

# 📊 Track Your Progress

See your preparation evolve over time.

## Progress Analytics

Track:

- Overall completion percentage
- Total cleared problems
- Topic-wise progress
- Difficulty-wise progress
- Weekly activity
- Daily completion patterns
- Weak topic areas
- Daily focus recommendations

### 🔥 70-Day Activity Heatmap

Visualize your consistency with a **70-day activity heatmap**.

See exactly when you were active and identify patterns in your preparation.

---

# 🔥 Gamification

Interview preparation is a long journey.

Neo 150 Prep makes consistency rewarding.

## XP & Levels

Earn XP by completing problems and progressing through the platform.

Track:

- Total XP
- Current level
- Level progression

---

## 🔥 Streaks

Build consistency through daily practice.

Track:

- Current streak
- Longest streak

The longest streak is preserved as a personal high-water mark.

---

## 🏆 Achievements

Unlock achievements as you reach important milestones.

Achievements track meaningful moments in your preparation journey and display:

- Locked/unlocked status
- Unlock dates
- Achievement descriptions
- Achievement icons

---

# 🤖 AI Coach

Sometimes you don't need the answer.

You need the **right direction**.

Neo 150 Prep includes an AI Coach that can provide:

### 💡 Progressive Hints

Get guidance without immediately revealing the solution.

### 🧠 High-Level Approaches

Understand how to think about a problem before implementing it.

The AI Coach is designed to guide your thinking rather than simply hand you complete solutions.

---

# 🎤 AI Mock Interviews

Practice explaining your thinking — not just writing code.

For completed problems, Neo 150 Prep allows you to start an AI-powered mock interview.

Each interview session includes:

1. AI-generated interview questions
2. Your written answers
3. AI feedback
4. Optional score out of 10
5. Saved interview history

The interview flow currently uses **two AI-generated questions per session**.

---

# 🧠 Interview History

Your interview practice is saved so you can look back at your progress.

Review:

- Questions
- Your answers
- AI feedback
- Scores

This allows you to track how your communication and problem-solving explanation improve over time.

---

# 🔔 Smart Notifications

Staying consistent is difficult.

Neo 150 Prep includes a notification system designed to remind you at the right time.

Supported reminder categories include:

### 📅 Daily Prep

Get reminded about your daily preparation.

### 🎯 Daily Goal

Receive reminders when your daily goal has not been completed.

### 🔥 Streak Protection

Get reminded when you have an active streak but haven't solved a problem today.

### 🏆 Achievements

Receive notifications when achievements are unlocked.

---

## Notification Architecture

The notification system supports:

### 🤖 Android

- Firebase Cloud Messaging
- Local foreground notifications
- Notification channels
- Token refresh handling

### 🌐 Web

- Browser Push API
- Web Push
- VAPID authentication
- Service worker notifications
- Notification click navigation

### ⚙️ Delivery System

The backend notification engine includes:

- Timezone-aware scheduling
- Logical delivery deduplication
- Retry attempts
- Delivery leases
- Multiple notification endpoints
- Invalid endpoint cleanup

---

# ☁️ Offline-First Cloud Sync

Your preparation should not stop when your internet connection does.

Neo 150 Prep uses an offline-first approach.

### Local Storage

Progress and preferences are stored locally.

### Optimistic Updates

Changes are reflected immediately in the UI.

### Mutation Queue

Offline changes are queued for synchronization.

### Cloud Reconciliation

Authenticated users can synchronize their progress with Supabase.

This includes:

- Problem progress
- Notes
- Goals
- Achievements
- Interview history
- Preferences
- Notification endpoints

---

# 🔐 Authentication

Authentication is powered by **Supabase Auth**.

Currently implemented:

### Google Sign-In

Users can sign in with Google to synchronize their preparation data across sessions.

Authentication flow:

```text
User
  │
  ▼
Google OAuth
  │
  ▼
Supabase Auth
  │
  ▼
Authenticated Session
  │
  ├── Cloud Sync
  ├── Progress Storage
  ├── Achievements
  ├── Interview History
  └── Notification Registration
````

---

# 🏗 Architecture

```text
                         ┌─────────────────────┐
                         │   Flutter Client    │
                         │                     │
                         │ Home                │
                         │ Problems            │
                         │ Interview           │
                         │ Progress            │
                         │ Achievements        │
                         │ Profile             │
                         └──────────┬──────────┘
                                    │
                 ┌──────────────────┴──────────────────┐
                 │                                     │
                 ▼                                     ▼
      ┌──────────────────────┐              ┌──────────────────────┐
      │     Local Storage    │              │       Supabase       │
      │                      │              │                      │
      │ Problem Dataset      │              │ Authentication       │
      │ SharedPreferences    │              │ PostgreSQL           │
      │ Offline Progress     │              │ Row Level Security   │
      │ Mutation Queue       │              │ Edge Functions       │
      └──────────────────────┘              └──────────┬───────────┘
                                                       │
                          ┌────────────────────────────┼────────────────────────────┐
                          │                            │                            │
                          ▼                            ▼                            ▼
                    ┌───────────┐                ┌───────────┐                ┌───────────┐
                    │ Gemini AI │                │    FCM    │                │ Web Push  │
                    │           │                │ Android   │                │  Browser  │
                    └───────────┘                └───────────┘                └───────────┘
```

---

# 🛠 Tech Stack

## Frontend

* Flutter
* Dart
* Material Design
* Riverpod

## Backend

* Supabase Auth
* Supabase PostgreSQL
* Supabase Row Level Security
* Supabase Edge Functions

## AI

* Gemini API

## Notifications

* Firebase Cloud Messaging
* Flutter Local Notifications
* Web Push
* VAPID

## Local Storage

* SharedPreferences
* Bundled JSON dataset

## Hosting

* Firebase Hosting

---

# 📱 Platforms

| Platform   |     Application |                                   Notifications |
| ---------- | --------------: | ----------------------------------------------: |
| 🌐 Web     |               ✅ |                                        Web Push |
| 🤖 Android |               ✅ |                        Firebase Cloud Messaging |
| 🍎 iOS     |               ✅ | Platform notification implementation may differ |
| 💻 Windows | Flutter support |                                               — |
| 🐧 Linux   | Flutter support |                                               — |
| 🍏 macOS   | Flutter support |                                               — |

---

# 🗂 Project Structure

```text
mins_prep/
│
├── lib/
│   ├── config/
│   │
│   ├── data/
│   │   └── Local persistence and dataset loading
│   │
│   ├── models/
│   │   └── Domain models
│   │
│   ├── providers/
│   │   └── Riverpod application state
│   │
│   ├── screens/
│   │   ├── Home
│   │   ├── Problems
│   │   ├── Interview
│   │   ├── Progress
│   │   ├── Achievements
│   │   └── Profile
│   │
│   ├── services/
│   │   ├── Supabase
│   │   ├── AI Coach
│   │   ├── Notifications
│   │   ├── Connectivity
│   │   └── Streaks
│   │
│   └── widgets/
│       └── Shared UI components
│
├── assets/
│   ├── data/
│   └── icons/
│
├── supabase/
│   ├── functions/
│   │   ├── ai-coach/
│   │   └── notification-engine/
│   │
│   ├── migrations/
│   └── schema.sql
│
├── test/
│
├── android/
├── ios/
├── web/
├── windows/
├── linux/
└── macos/
```

---

# 🚀 Getting Started

## Prerequisites

Make sure you have installed:

* Flutter
* Dart
* A Supabase project
* Firebase configuration for Android
* A Gemini API key for AI features
* Web Push VAPID keys for browser notifications

---

## 1️⃣ Clone the Repository

```bash
git clone YOUR_REPOSITORY_URL
```

```bash
cd mins_prep
```

---

## 2️⃣ Install Dependencies

```bash
flutter pub get
```

---

## 3️⃣ Configure Environment

The Flutter client uses a compile-time Web Push public key.

Run with:

```bash
flutter run \
  --dart-define=WEB_PUSH_VAPID_PUBLIC_KEY=YOUR_VAPID_PUBLIC_KEY
```

---

# 🌐 Run on Web

```bash
flutter run \
  -d chrome \
  --dart-define=WEB_PUSH_VAPID_PUBLIC_KEY=YOUR_VAPID_PUBLIC_KEY
```

---

# 📱 Build Android APK

```bash
flutter build apk \
  --release \
  --dart-define=WEB_PUSH_VAPID_PUBLIC_KEY=YOUR_VAPID_PUBLIC_KEY
```

The generated APK will be available at:

```text
build/app/outputs/flutter-apk/app-release.apk
```

---

# 🌐 Build for Web

```bash
flutter build web \
  --release \
  --dart-define=WEB_PUSH_VAPID_PUBLIC_KEY=YOUR_VAPID_PUBLIC_KEY
```

The production build will be generated in:

```text
build/web/
```

---

# 🧪 Testing

The project includes tests covering core logic such as:

* Streak calculation
* AI Coach context
* Notification delivery
* Notification retries
* Endpoint deactivation
* Notification deduplication
* Timezone handling

Run Flutter tests:

```bash
flutter test
```

---

# 📊 By the Numbers

<div align="center">

|                                    |             |
| ---------------------------------- | ----------: |
| 🧩 Problems                        |     **150** |
| 🏷 Categories                      |      **18** |
| 📱 Main App Sections               |       **6** |
| 📅 Activity Heatmap                | **70 Days** |
| 🎤 Interview Questions per Session |       **2** |
| 🔔 Notification Categories         |       **4** |

</div>

---

# 🧭 Main App Sections

Neo 150 Prep is organized into six main areas:

### 🏠 Home

Your daily preparation dashboard.

### 🧩 Problems

The complete NeetCode 150 problem library.

### 🎤 Interview

AI-powered mock interview practice.

### 📊 Progress

Analytics, heatmaps, streaks, and topic performance.

### 🏆 Achievements

Track milestones and unlock achievements.

### 👤 Profile

Goals, notifications, sync, export, and account settings.

---

# 📚 Dataset

The application contains a curated dataset of **150 coding interview problems** based on the NeetCode 150 problem set.

Each problem includes:

* Title
* Topic
* Difficulty
* Ordering
* External problem URL

Please refer to the original problem sources for problem statements and intellectual property ownership.

---

# 🔒 Privacy & Data

Neo 150 Prep stores user-specific preparation data only to support features such as:

* Progress synchronization
* Notes
* Goals
* Achievements
* Interview history
* Notification preferences

User-owned database records are protected through Supabase Row Level Security policies.

---

# 🧠 Philosophy

Coding interview preparation isn't about solving hundreds of random problems.

It's about:

```text
Consistency
      ↓
Pattern Recognition
      ↓
Better Problem Solving
      ↓
Confidence
```

Neo 150 Prep is designed to support that journey.

---

# 🚧 Roadmap

Future ideas may include:

* ⏱ Focus mode and preparation timer
* 📈 Additional analytics
* 🏅 More achievements
* 🎯 Personalized preparation recommendations
* 📱 Expanded platform-specific notification support
* 🧠 Additional AI coaching modes

---

# 🤝 Contributing

Contributions, ideas, and feedback are welcome.

If you find a bug or have a feature idea:

1. Open an issue.
2. Describe the problem or proposal.
3. If possible, submit a pull request.

---

# 📄 License

This project is intended as a portfolio and learning project.

Please review the repository license before reusing or redistributing the code.

---

<div align="center">

## 🚀 Build consistency. Track progress. Get better.

### Neo 150 Prep

**Your journey through the NeetCode 150 — one problem at a time.**

<br />

Made with ❤️ using Flutter, Supabase, Firebase, and AI.

</div>
