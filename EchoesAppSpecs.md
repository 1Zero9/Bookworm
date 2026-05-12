Since you're building a versatile creative tool in Swift, the goal is to create a Modular Content Engine. This structure ensures that whether you're writing hard sci-fi, a period drama, or a technical manual, the AI understands the "Laws of the World" before it starts generating text.

Here is a generic, high-level System Specification you can use for your app's documentation and Claude Code instructions.

Header 1: THE CREATIVE ENGINE — APP BLUEPRINT
Header 2: Data Architecture
The app should store project data in three distinct layers to provide the AI with perfect context:

The Core Ledger (Global Context): High-level rules, world-building, and "Never-Break" constraints (e.g., Tone, Spelling, Magic/Tech systems).

The Character Vault (Entity Context): Detailed profiles including physical traits, psychological flaws, and "Personal Texture."

The Active Draft (Local Context): The current scene or chapter being written.

Header 2: AI Persona Framework
To maximize the API's utility, the app should toggle between these modes based on the user's active view:

Persona: The Architect (Drafting Mode)
Focus: Narrative flow, sensory immersion, and dialogue.

Directive: Avoid "Wiki-voice" and exposition dumping.

Mechanism: Uses "Show, Don't Tell" logic. It receives the Character Vault and Active Draft as primary context.

Persona: The Archivist (Research Mode)
Focus: Logical consistency and fact-retrieval.

Directive: Provide dry, technical, or historical data based on the Core Ledger.

Mechanism: Acts as a "Search Engine" for the user's own world-building notes.

Header 2: Feature Specifications for Swift/Xcode
1. Smart Context Injection (ContextManager.swift)
The API call should not be a "naked" prompt. Before sending the user’s request, the app must:

Prepend the Project Style Guide (e.g., "Use UK English," "Tone: Dark/Gritty").

Inject relevant Character Profiles if names from the Character Vault are detected in the active text buffer.

Limit the Active Draft window to the last 1,500 words to save tokens and maintain focus.

2. The Visual Director (Image Generation Pipeline)
Input: High-level prose from the editor.

Processing: The API "distills" the prose into a visual-only descriptor (Lighting, Mood, Subject, Palette).

Output: Triggers an image generation API to provide a visual anchor for the scene.

3. The "Narrative Audit" (Review Feature)
A dedicated "Review" button that specifically asks the AI to find:

Clichés: Overused metaphors or "important-sounding" clusters.

Wiki-voice: Sections where the author is explaining the world instead of showing it.

Emotional Gaps: Where a character's reaction feels unearned or missing.

Header 2: Implementation Prompts (For Claude Code)
To build the Context Manager:

"Write a Swift class called ContextManager that takes a String of user text, checks it against a local JSON of character names, and returns a combined String formatted for an LLM prompt. The output must include the Project Ledger, relevant Character Data, and the user's text."

To build the Markdown Export:

"Create a SwiftUI function to export the current Document Model as a .md file. The file should be structured with Header 1 for the Project Title and Header 2 for Chapter titles, followed by a 'Ledger' section at the bottom for manual AI syncing."