# Safety and AI disclosure

Core is a local UE4SS mod. It does not bundle a loader, custom playable character, character texture pack, or movie. It does include shared UI/cooked shader and skeleton compatibility resources, the Original thumbnail, Lua scripts and an unsigned native helper DLL. The manual energy-refill button changes the local player's ability resource on demand, so this is not exclusively a visual modification.

The helper supports local movie-audio decoding/output, directory listing and user-requested Explorer opening. Movies are imported as local files; the manager is not an automatic downloader or updater. Source inspection, checksums and zero antivirus detections do not establish absolute safety. Do not bypass security products to use the mod; report concrete detections for investigation.

As checked on 5 November 2026, Nexus mod 554's optional Source Review file 1906 was quarantined by automatic safety checks, while the main Core file 1903 showed download controls. Linked VirusTotal reports showed 0/65 for the source ZIP and 0/63 for Core. The exact internal Nexus trigger was not disclosed. The source ZIP includes build.cmd, which might require manual file-type review; that is an inference, not a confirmed cause. This GitHub publication does not resolve or override the Nexus review.

- Main SHA256: cdc7d26e065ae087265265452d22ecbd341940f75977e4d8a35e33e008d7b2f3
- Source Review SHA256: 2082ec7a61493448763281c2d90e41aa35508d41efc045989b85df10caaa0585
- Nexus: https://www.nexusmods.com/phantombladezero/mods/554?tab=files

OpenAI Codex / ChatGPT contributed code, UI, original Shader integration and documentation. The user directed features and performed repeated real-game checks. The screenshot is a user-provided game capture, not a generated image. On Nexus the page carries AI-Generated Content and AI Media tags. Source availability is not presented as evidence that the work was entirely human-written.

When reporting a problem, give the game build, Core/character versions, reproduction steps and relevant redacted log excerpts. Do not post credentials, account recovery links, game keys, saves, personal paths or complete crash dumps in public issues.
