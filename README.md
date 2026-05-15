# Reverie
A proactive AI productivity system for students who want to live with intention, not just manage a to-do list

## Problem
Most productivity apps solve the wrong problem. They are excellent at capture, getting things out of your head and into a list. But they stop there. Once a task is entered, the system becomes passive. It waits. It reminds. It does not reason.
The result is a system that reflects what you said you would do, not what you are actually doing. Important goals sit quietly alongside grocery runs with no signal that one has been untouched for six weeks. Your health goals coexist with assignment deadlines in the same list. Nothing flags that your relationships domain has had zero activity this month. No one notices that you keep completing small, easy tasks while rescheduling the one hard thing that actually matters.
Generic habit trackers do not solve this either. They track streaks, not meaning. They reward consistency without asking whether what you are being consistent about is aligned with who you are trying to become.
What is missing is a layer of intelligence over the whole picture, something that understands the structure of a life, not just a task list.

## Solution
Reverie is a native iOS app built around three interconnected layers:

### Structure: 
An 8-domain life framework (Health, Career, Relationships, Learning, Creativity, Finance, Home, Personal) with four entity types: Plans (domain buckets), Journeys (time-bound goals with milestones), Routines (recurring practices), and Tasks (individual work units). The fixed domains are not a limitation. They are what makes domain-level intelligence meaningful. You can only detect that Health has gone quiet if Health is a defined, consistent category.

### Intelligence:
Lumina, an AI companion that runs proactively in the background every 6 hours. It analyses your task and goal history across all domains, detects patterns you would not notice yourself, and surfaces personalised nudges and a daily briefing without any user action required. It also supports conversational task capture and semantic search over your past notes.

### Reflection:
A Growth Mindset Engine that measures resilience and recovery, not just streaks. It records behavioral events (missed, rescheduled, recovered, abandoned), generates confidence-scored insights from 30-day histories, and surfaces patterns in how you actually work, not how you intended to work.

##The core design principle: the gap between intention and action is not a motivation problem. It is a visibility problem.

## Demo

## System Design

Reverie is built around a local-first data model with 24 SwiftData entities as its foundation. Everything lives on device by default: Plans, Journeys, Milestones, Routines, Tasks, behavioral event logs, conversation history, and AI-generated insights. iCloud sync via CloudKit is available but opt-in.

