# Generated code, not human-reviewed.
"""Add words from your AI agent chats to the pro-prose word list.

1. Count the words in your Claude Code and Compass chats (your messages and
   the agent's text replies), on this machine. Only plain words count:
   tokens with digits, underscores, slashes or inner capitals (code, paths,
   keys) are skipped.
2. Words used a few times that no list knows yet are candidates. Only the
   candidate words, never sentences, go to an AI agent for review. Agents
   are tried in this order: Claude Code, Compass, Codex, then OpenRouter. If
   one fails, the next one is tried. The agent drops typos and anything
   private or project-specific.
3. Approved words are merged into chat-words.txt: never replaced, never
   removed, and a word's count only grows. Deleting old chats cannot shrink
   the list. To drop a word, delete its line by hand.

The agent's verdict on every word is cached, so a word is reviewed once.
Files are saved after every batch, the word list first, so an interrupted
sync keeps what it finished. Only one sync runs at a time.

Usage: python3 -I sync.py --data-dir DIR --wordfreq FILE [--user-words FILE[,FILE]]
                          [--claude-dir DIR] [--compass-dir DIR]
"""

import argparse
import collections
import fcntl
import glob
import json
import os
import re
import shutil
import subprocess
import urllib.request

MIN_COUNT = 3
MIN_LENGTH = 3
MAX_CANDIDATES = 1500
BATCH = 300

# A word: letters (any script), with at most one inner apostrophe.
WORD = re.compile(r"[^\W\d_]+(?:'[^\W\d_]+)?")
# Punctuation that may wrap a word in running text.
WRAPPING = "\"'`*_()[]{}<>.,;:!?“”‘’«»…—–-"
# Text the harness wrote itself into a user message.
GENERATED = (
    "<command-",
    "<local-command-",
    "<task-notification>",
    "[Request interrupted",
    "<skill ",
)

REVIEW_PROMPT = """Below are words taken from a software developer's chats with their AI coding agent. They will go into a personal autocomplete dictionary that may later be shared with teammates.

Keep a word if it is a correctly spelled English or French word, or a widely known public technical term (a programming language, framework, tool, protocol or file format known outside any one company, e.g. "kubernetes", "idempotent", "postgres", "neovim").

Drop a word if it is:
- a misspelling of another word (e.g. "thsi", "commot");
- a person's name, or a company, client or customer name;
- an internal project, product, team or code name, an internal hostname, or an identifier;
- anything else that looks private, confidential or specific to one organisation;
- not a word (fragments, random letters).

When unsure, drop it.

Answer with JSON only, in this form: {"keep": ["word", ...]}

Words:
"""


def text_of(content):
    if isinstance(content, str):
        return content
    return "\n".join(
        b.get("text", "")
        for b in content or []
        if isinstance(b, dict) and b.get("type") == "text"
    )


def is_own_text(text):
    """Whether a message is the person's or the agent's own text: not one the
    harness wrote, and not a review prompt from an earlier sync."""
    return (
        bool(text)
        and not text.startswith(GENERATED)
        and not text.startswith(REVIEW_PROMPT[:80])
    )


def read_jsonl(path):
    with open(path, encoding="utf-8", errors="replace") as f:
        for line in f:
            try:
                record = json.loads(line)
            except ValueError:
                continue
            if isinstance(record, dict):
                yield record


def claude_texts(root):
    for path in glob.glob(os.path.join(root, "projects", "*", "*.jsonl")):
        for record in read_jsonl(path):
            message = record.get("message")
            if (
                not isinstance(message, dict)
                or record.get("isSidechain")
                or record.get("isMeta")
            ):
                continue
            if record.get("isCompactSummary") or record.get("type") not in (
                "user",
                "assistant",
            ):
                continue
            text = text_of(message.get("content")).strip()
            if is_own_text(text):
                yield text


def compass_texts(root):
    for path in glob.glob(os.path.join(root, "sessions", "*", "*.jsonl")):
        for entry in read_jsonl(path):
            message = entry.get("message") if entry.get("type") == "message" else None
            if not isinstance(message, dict) or message.get("role") not in (
                "user",
                "assistant",
            ):
                continue
            text = text_of(message.get("content")).strip()
            if is_own_text(text):
                yield text


def words_in(text):
    """The plain words of a text, lowercased. Tokens are split on whitespace
    first, so a key, path or identifier is skipped whole, not cut into
    letter fragments."""
    for token in text.split():
        token = token.strip(WRAPPING).replace("’", "'")
        if not WORD.fullmatch(token) or any(c.isupper() for c in token[1:]):
            continue
        word = token.lower()
        # A possessive counts as its word: "dev's" as "dev".
        yield word[:-2] if word.endswith("'s") else word


def count_words(claude_dir, compass_dir):
    counts = collections.Counter()
    for text in list(claude_texts(claude_dir)) + list(compass_texts(compass_dir)):
        counts.update(words_in(text))
    return counts


def read_json(path, default):
    try:
        with open(path, encoding="utf-8") as f:
            return json.load(f)
    except (OSError, ValueError):
        return default


def write_atomic(path, text):
    """Write through a temporary file renamed over the old one, so a crash
    mid-write cannot leave a truncated file."""
    tmp = f"{path}.{os.getpid()}.tmp"
    with open(tmp, "w", encoding="utf-8") as f:
        f.write(text)
    os.replace(tmp, path)


def read_chat_words(path):
    words = {}
    if os.path.exists(path):
        with open(path, encoding="utf-8") as f:
            for line in f:
                word, _, count = line.rstrip("\n").partition("\t")
                if word and count.isdigit():
                    words[word] = int(count)
    return words


def write_chat_words(path, chat):
    lines = (
        f"{w}\t{n}\n"
        for w, n in sorted(chat.items(), key=lambda item: (-item[1], item[0]))
    )
    write_atomic(path, "".join(lines))


def read_user_words(paths):
    words = set()
    for path in filter(None, paths.split(",")):
        if os.path.exists(path):
            with open(path, encoding="utf-8") as f:
                words.update(
                    line.split("/")[0].strip().lower() for line in f if "/!" not in line
                )
    return words


def available_agents(work_dir):
    """The reviewers on this machine, in order of preference, as (name, function
    that sends a prompt and returns the reply).

    Each agent runs in work_dir (the data folder) with no tools and without
    saving a session, so it doesn't pick up a project's instructions, hooks or
    files, and doesn't leave a transcript for the next sync to count."""
    # A Neovim opened from Claude Code (Ctrl+G) inherits these; a nested
    # `claude -p` can refuse to start with them set.
    env = {
        k: v
        for k, v in os.environ.items()
        if k not in ("CLAUDECODE", "CLAUDE_CODE_ENTRYPOINT")
    }

    def command(args, use_stdin):
        def run(prompt):
            result = subprocess.run(
                args if use_stdin else args + [prompt],
                input=prompt if use_stdin else None,
                capture_output=True,
                text=True,
                timeout=600,
                cwd=work_dir,
                env=env,
            )
            if result.returncode != 0:
                raise RuntimeError(
                    result.stderr.strip()[:300] or f"exit code {result.returncode}"
                )
            return result.stdout

        return run

    agents = []
    if shutil.which("claude"):
        args = [
            "claude",
            "-p",
            "--model",
            "haiku",
            "--no-session-persistence",
            "--tools",
            "",
        ]
        agents.append(("Claude Code", command(args, True)))
    if shutil.which("compass"):
        args = [
            "compass",
            "-p",
            "--no-tools",
            "--no-session",
            "--no-extensions",
            "--no-skills",
        ]
        agents.append(("Compass", command(args, False)))
    if shutil.which("codex"):
        args = ["codex", "exec", "--sandbox", "read-only", "--skip-git-repo-check"]
        agents.append(("Codex", command(args, False)))
    if os.environ.get("OPENROUTER_API_KEY"):

        def openrouter(prompt):
            body = {
                "model": "anthropic/claude-haiku-5.5",
                "messages": [{"role": "user", "content": prompt}],
                "reasoning": {"effort": "none"},
            }
            request = urllib.request.Request(
                "https://openrouter.ai/api/v1/chat/completions",
                data=json.dumps(body).encode(),
                headers={
                    "Authorization": "Bearer " + os.environ["OPENROUTER_API_KEY"],
                    "Content-Type": "application/json",
                },
            )
            return json.load(urllib.request.urlopen(request, timeout=300))["choices"][
                0
            ]["message"]["content"]

        agents.append(("OpenRouter", openrouter))
    return agents


def review(agents, words):
    """The words the first working agent keeps, and that agent's name.
    Raises RuntimeError when every agent fails."""
    errors = []
    for name, ask in agents:
        try:
            reply = ask(REVIEW_PROMPT + "\n".join(words))
            # Read the first JSON object; agents sometimes add a remark after it.
            kept, _ = json.JSONDecoder().raw_decode(reply[reply.index("{") :])
            return {w for w in kept.get("keep", []) if w in words}, name
        except Exception as error:  # any failure means: try the next agent
            errors.append(f"{name}: {error}")
    raise RuntimeError("every agent failed:\n  " + "\n  ".join(errors))


def main():
    parser = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter
    )
    parser.add_argument("--data-dir", required=True)
    parser.add_argument("--wordfreq", required=True)
    parser.add_argument("--user-words", default="")
    parser.add_argument(
        "--claude-dir",
        default=os.environ.get("CLAUDE_CONFIG_DIR") or os.path.expanduser("~/.claude"),
    )
    parser.add_argument(
        "--compass-dir",
        default=os.environ.get("COMPASS_CODING_AGENT_DIR")
        or os.path.expanduser("~/.compass/agent"),
    )
    args = parser.parse_args()

    os.makedirs(args.data_dir, exist_ok=True)
    chat_file = os.path.join(args.data_dir, "chat-words.txt")
    cache_file = os.path.join(args.data_dir, "review-cache.json")

    # One sync at a time; the lock is released when the process ends.
    lock = open(os.path.join(args.data_dir, "sync.lock"), "w")
    try:
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except BlockingIOError:
        raise SystemExit("Another sync is already running.")

    wordfreq = read_json(args.wordfreq, [])
    if not wordfreq:
        # Without the common words, every chat word would look new.
        raise SystemExit(
            "The wordfreq list is missing; open a prose file in Neovim to download it, then sync again."
        )
    known = {entry[0] for entry in wordfreq} | read_user_words(args.user_words)

    chat = read_chat_words(chat_file)
    cache = read_json(cache_file, {})
    counts = count_words(args.claude_dir, args.compass_dir)
    # Words already in the list keep the higher of their old and new counts.
    for word in chat:
        chat[word] = max(chat[word], counts.get(word, 0))
    write_chat_words(chat_file, chat)

    candidates = [
        w
        for w, n in counts.most_common()
        if n >= MIN_COUNT
        and len(w) >= MIN_LENGTH
        and w not in known
        and w not in chat
        and w not in cache
    ][:MAX_CANDIDATES]
    if not candidates:
        print(f"No new words. {len(chat)} words in the chat list.")
        return

    agents = available_agents(args.data_dir)
    if not agents:
        raise SystemExit(
            "No AI agent found (claude, compass, codex or OPENROUTER_API_KEY); nothing added. "
            "Words are only added after a review."
        )

    added, used = 0, set()
    for i in range(0, len(candidates), BATCH):
        batch = candidates[i : i + BATCH]
        try:
            kept, name = review(agents, batch)
        except RuntimeError as error:
            raise SystemExit(
                f"Stopped after {added} new words; the rest are left for the next sync. Review {error}"
            )
        used.add(name)
        for w in kept:
            chat[w] = counts[w]
        added += len(kept)
        # The list first, then the verdicts: a word cached as reviewed is
        # always already in the list.
        write_chat_words(chat_file, chat)
        cache.update({w: w in kept for w in batch})
        write_atomic(cache_file, json.dumps(cache, indent=0, sort_keys=True))
    print(f"Reviewed {len(candidates)} words with {', '.join(sorted(used))}.")
    print(f"{added} words added, {len(chat)} words in the chat list.")


if __name__ == "__main__":
    main()
