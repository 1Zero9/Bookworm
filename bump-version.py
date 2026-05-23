#!/usr/bin/env python3
import os
import re
from datetime import datetime

# Define file paths
THEME_FILE = "Sources/Bookworm/AppTheme.swift"
VERSION_FILE = "version.txt"
BUILD_FILE = "build.txt"
RELEASE_NOTES_FILE = "RELEASE_NOTES.md"
README_FILE = "README.md"
WALKTHROUGH_FILE = "/Users/stephencranfield/.gemini/antigravity/brain/4b9e9e92-e080-4d0f-b439-d098642c6eaa/walkthrough.md"

def get_current_version_and_build():
    version = "2.7.3"
    build = 6

    # Read from version.txt
    if os.path.exists(VERSION_FILE):
        with open(VERSION_FILE, "r") as f:
            version = f.read().strip()
    else:
        # Fallback to parsing AppTheme.swift
        if os.path.exists(THEME_FILE):
            with open(THEME_FILE, "r") as f:
                content = f.read()
                match = re.search(r'static let version = "v([^"]+)"', content)
                if match:
                    version = match.group(1)

    # Read from build.txt
    if os.path.exists(BUILD_FILE):
        with open(BUILD_FILE, "r") as f:
            try:
                build = int(f.read().strip())
            except ValueError:
                pass

    return version, build

def bump_version_string(version_str):
    parts = version_str.split('.')
    if len(parts) == 3:
        try:
            major, minor, patch = int(parts[0]), int(parts[1]), int(parts[2])
            patch += 1
            return f"{major}.{minor}.{patch}"
        except ValueError:
            pass
    return version_str + ".1"

def update_theme_file(version, build):
    if not os.path.exists(THEME_FILE):
        return False
    with open(THEME_FILE, "r") as f:
        content = f.read()
    
    content, count1 = re.subn(
        r'static let version = "v[^"]+"',
        f'static let version = "v{version}"',
        content
    )
    
    content, count2 = re.subn(
        r'static let build = "[^"]+"',
        f'static let build = "{build}"',
        content
    )
    
    if count1 > 0 or count2 > 0:
        with open(THEME_FILE, "w") as f:
            f.write(content)
        return True
    return False

def update_walkthrough_file(version):
    if not os.path.exists(WALKTHROUGH_FILE):
        return False
    with open(WALKTHROUGH_FILE, "r") as f:
        content = f.read()
    
    # Update version header in walkthrough
    new_content, count = re.subn(
        r'# Walkthrough: Bookworm v\d+\.\d+\.\d+ Release Features',
        f'# Walkthrough: Bookworm v{version} Release Features',
        content
    )
    
    if count > 0:
        with open(WALKTHROUGH_FILE, "w") as f:
            f.write(new_content)
        return True
    return False

def update_readme_file(version, build):
    if not os.path.exists(README_FILE):
        return False
    with open(README_FILE, "r") as f:
        content = f.read()
    
    # 1. Update title version: (vX.Y.Z) -> (v{version})
    content, count1 = re.subn(
        r'# Bookworm — The Modern Creative Writing Studio \(v\d+\.\d+\.\d+\)',
        f'# Bookworm — The Modern Creative Writing Studio (v{version})',
        content
    )
    
    # 2. Update version badge: version-X.Y.Z-C9963A
    content, count2 = re.subn(
        r'version-\d+\.\d+\.\d+-C9963A',
        f'version-{version}-C9963A',
        content
    )
    
    # 3. Update build badge: build-N-7C8CFF
    content, count3 = re.subn(
        r'build-\d+-7C8CFF',
        f'build-{build}-7C8CFF',
        content
    )
    
    if count1 > 0 or count2 > 0 or count3 > 0:
        with open(README_FILE, "w") as f:
            f.write(content)
        return True
    return False

def append_release_notes(version, build):
    date_str = datetime.now().strftime("%B %d, %Y")
    
    new_notes = f"""# Bookworm Release Notes

## Version {version} (Build {build}) — {date_str}
- Automatically incremented app build and release notes configuration.
- Unified and optimized all mouseover button tooltips via robust native AppKit `TooltipView` bridge.
- Bypassed SwiftUI custom ButtonStyle hover event interception conflicts globally.
- Hardened thread-safety, secure Keychain encryption, and DP LCS Compare systems.

"""
    
    if os.path.exists(RELEASE_NOTES_FILE):
        with open(RELEASE_NOTES_FILE, "r") as f:
            content = f.read()
        
        if "# Bookworm Release Notes" in content:
            updated_content = content.replace("# Bookworm Release Notes\n", "")
            updated_content = updated_content.replace("# Bookworm Release Notes", "")
            full_notes = f"# Bookworm Release Notes\n\n## Version {version} (Build {build}) — {date_str}\n- Automatically incremented app build and release notes configuration.\n- Unified and optimized all mouseover button tooltips via robust native AppKit `TooltipView` bridge.\n- Bypassed SwiftUI custom ButtonStyle hover event interception conflicts globally.\n- Hardened thread-safety, secure Keychain encryption, and DP LCS Compare systems.\n\n" + updated_content.strip()
        else:
            full_notes = f"# Bookworm Release Notes\n\n## Version {version} (Build {build}) — {date_str}\n- Automatically incremented app build and release notes configuration.\n- Unified and optimized all mouseover button tooltips via robust native AppKit `TooltipView` bridge.\n- Bypassed SwiftUI custom ButtonStyle hover event interception conflicts globally.\n- Hardened thread-safety, secure Keychain encryption, and DP LCS Compare systems.\n\n" + content.strip()
    else:
        full_notes = new_notes

    with open(RELEASE_NOTES_FILE, "w") as f:
        f.write(full_notes)

def main():
    version, build = get_current_version_and_build()
    new_version = bump_version_string(version)
    new_build = build + 1

    print(f"Bumping version: {version} (Build {build}) -> {new_version} (Build {new_build})")

    # Update version.txt and build.txt
    with open(VERSION_FILE, "w") as f:
        f.write(new_version)
    with open(BUILD_FILE, "w") as f:
        f.write(str(new_build))

    # Update source/script files
    t_updated = update_theme_file(new_version, new_build)
    w_updated = update_walkthrough_file(new_version)
    r_updated = update_readme_file(new_version, new_build)
    append_release_notes(new_version, new_build)

    print("✅ Files updated successfully:")
    print(f"  - AppTheme.swift: {'Yes' if t_updated else 'No'}")
    print(f"  - walkthrough.md: {'Yes' if w_updated else 'No'}")
    print(f"  - README.md: {'Yes' if r_updated else 'No'}")
    print(f"  - RELEASE_NOTES.md: Yes")

if __name__ == "__main__":
    main()
