
import sys
import subprocess
from dataclasses import dataclass
from pathlib import Path

def gather_context(file_path: str, line_number: int, selection: 'EditorSelection'):
    # Read file into lines
    with open(file_path, 'r') as f:
        lines = f.readlines()

    total_lines = len(lines)
    index = line_number - 1  # Convert to 0-based index

    if index < 0 or index >= total_lines:
        print(f"Error: Line number {line_number} is out of bounds.")
        sys.exit(1)

    # Extract the text content of the selection using the 'selection' argument
    selected_lines = lines[selection.start_line - 1:selection.end_line]

    # Handle the first line separately if it starts mid-line
    if selected_lines:
        selected_lines[0] = selected_lines[0][selection.start_column:]

    # Handle the last line separately if it ends mid-line
    if len(selected_lines) > 1:
        selected_lines[-1] = selected_lines[-1][:selection.end_column]

    # Join the selected lines to form the final selection text
    selection_txt = '\n'.join(selected_lines).strip()

    # We also want the whole file
    whole_file = '\n'.join(lines)

    context = f"""\
Selected Text: 
### selected text ###
{selection_txt}
### / selected text ###
 
Whole File: 
### whole file ###
{whole_file}
### / whole file ###
    """

    return context

def run_sgpt_with_context(context, file_ext: str):
    # print("call sgpt with context:\nvvvvvCONTEXTvvvvv")
    # print(context)
    # print("^^^^^CONTEXT^^^^^")

    prompt = f"""\
You are an expert senior staff principle software engineer specializing in simplicity and almost haiku like natural 
abiltiy with writing code snippets.  You're an expert at all well known programming langauges.
The file extension you're writing in is: ${file_ext}
You will be given a user prompt, the entire file, and the current selection.  You can use the entire file for context, but ONLY generate code to replace the SELECTION in a way appropriate for the context, and nothing else.
You will be precise when needed, if an instruction doesn't 
make sense, you automatically adjust to do the right thing: DWIM philosophy.
Ensure you maintain consistent formatting and indentation when the code is injected back in.

${context}
"""

    try:
        # Run sgpt --code and pass the context via stdin
        result = subprocess.run(
            ['sgpt', '--code'],
            input=prompt.encode('utf-8'),
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE
        )

        if result.returncode != 0:
            print("sgpt failed:", result.stderr.decode('utf-8'))
            sys.exit(1)

        output = result.stdout.decode('utf-8')

        # Copy to clipboard using pbcopy
        pbcopy = subprocess.run(
            ['pbcopy'],
            input=output.encode('utf-8'),
            stderr=subprocess.PIPE
        )


        if pbcopy.returncode != 0:
            print("pbcopy failed:", pbcopy.stderr.decode('utf-8'))
            sys.exit(1)

        # print("Response output copied to clipboard:\nvvvvvOUTPUTvvvvv")
        # print(output)
        # print("^^^^^OUTPUT^^^^^")

        # print("!!!!")
        # for line in context.splitlines():
        #     print(line)
        # print("!!!!")


        # Paste
        paste_proc = subprocess.run(
            [
                "osascript",
                "-e",
                'tell application "System Events" to keystroke "v" using command down'
            ],
            input=output.encode('utf-8'),
            stderr=subprocess.PIPE
        )

        if paste_proc.returncode != 0:
            print("paste_proc failed:", paste_proc.stderr.decode('utf-8'))
            sys.exit(1)

        print("Pasted!")

    except FileNotFoundError as e:
        print(f"Error: {e}")
        sys.exit(1)

@dataclass
class EditorSelection:
    start_line: int
    end_line: int
    start_column: int
    end_column: int

def main():
    file_path = sys.argv[1]
    line_number = int(sys.argv[2])

    selection = EditorSelection(
        start_line=int(sys.argv[3]),
        end_line=int(sys.argv[5]),
        start_column=int(sys.argv[4]),
        end_column=int(sys.argv[6]),
    )

    print("!!!!!")
    print("selection lines:")
    print(selection.start_line)
    print(selection.end_line)
    print("selection cols:")
    print(selection.start_column)
    print(selection.end_column)
    print("!!!!!")
    # Optionally do something with py_interpreter_dir if needed
    if not Path(file_path).exists():
        print(f"Error: File '{file_path}' not found.")
        sys.exit(1)

    context = gather_context(file_path, line_number, selection)
    run_sgpt_with_context(context, Path(file_path).suffix)

if __name__ == '__main__':
    main()



