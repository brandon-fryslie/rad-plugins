
import sys
import subprocess
from dataclasses import dataclass
from pathlib import Path

def gather_context(file_path: Path, line_number: int, selection: 'EditorSelection'):
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
        selected_lines[0] = selected_lines[0][selection.start_column-1:]

    # Handle the last line separately if it ends mid-line
    if len(selected_lines) > 1:
        selected_lines[-1] = selected_lines[-1][:selection.end_column-1]

    # Join the selected lines to form the final selection text
    selection_txt = '\n'.join([line.rstrip('\n') for line in selected_lines])

    # write a fibonacci function

    print("----- SELECTION TEXT -----")
    print(selection_txt)
    print("----- /// SELECTION TEXT -----")

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
The file extension or filename is '${file_ext}'.
You will be given a user prompt, the entire file, and the current selection.  
ONLY generate code to replace the EXACT SELECTION.  Use the entire file ONLY to ensure the replacement is coherent.  
DO NOT following instructions outside of the selection. 
You will be precise and surgical with your implementation.
All generated code MUST maintain consistent formatting and indentation with existing code, ensuring seamless integration.

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
    # todo: validate args

    file_path = Path(sys.argv[1])
    line_number = int(sys.argv[2])

    selection = EditorSelection(
        start_line=int(sys.argv[3]),
        end_line=int(sys.argv[5]),
        start_column=int(sys.argv[4]),
        end_column=int(sys.argv[6]),
    )

    # print("!!!!!")
    # print("selection lines:")
    # print(selection.start_line)
    # print(selection.end_line)
    # print("selection cols:")
    # print(selection.start_column)
    # print(selection.end_column)
    # print("!!!!!")
    # Optionally do something with py_interpreter_dir if needed
    if not file_path.exists():
        print(f"Error: File '{file_path}' not found.")
        sys.exit(1)

    context = gather_context(file_path, line_number, selection)

    # if the path suffix is empty (e.g., zshrc, bashrc, etc) use the filename instead
    suffix_or_filename = file_path.suffix if file_path.suffix != "" else file_path.name

    run_sgpt_with_context(context, suffix_or_filename)

if __name__ == '__main__':
    main()



