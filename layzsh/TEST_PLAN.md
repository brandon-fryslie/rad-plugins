### LayZsh Test Plan

#### Overview
This test plan aims to verify the functionality of LayZsh, focusing on its ZLE widgets and AI integration features. The tests will ensure that key bindings, prompt modifications, and AI interactions work as expected.

#### Tools
- **ZUnit**: A unit testing framework for Zsh.
- **Expect**: A tool for automating interactive applications.

#### Test Cases

1. **Toggle LayZsh Activation**
   - **Objective**: Verify that the LayZsh activation toggles correctly and modifies the prompt.
   - **Steps**:
     1. Simulate pressing `opt+i, opt+i`.
     2. Check if the prompt includes the eyeball emoji when activated.
     3. Simulate pressing `opt+i, opt+i` again.
     4. Check if the prompt returns to its default state.
   - **Expected Result**: The prompt should toggle between the default and modified states.

2. **Submit a Prompt as a Chat**
   - **Objective**: Ensure that submitting a prompt as a chat works and returns a response.
   - **Steps**:
     1. Activate LayZsh.
     2. Simulate pressing `opt+i, opt+j`.
     3. Enter a sample prompt.
     4. Verify that a response is received from the AI.
   - **Expected Result**: The AI should return a response to the submitted prompt.

3. **Generate Shell Commands**
   - **Objective**: Test the conversion of plain English into shell commands.
   - **Steps**:
     1. Activate LayZsh.
     2. Simulate pressing `opt+i, opt+k`.
     3. Enter a natural language command.
     4. Verify that a valid shell command is generated.
   - **Expected Result**: The AI should generate a corresponding shell command.

4. **History Logging**
   - **Objective**: Verify that history is logged only when LayZsh is active.
   - **Steps**:
     1. Activate LayZsh and run a command.
     2. Check the history file for the logged command.
     3. Deactivate LayZsh and run another command.
     4. Verify that the second command is not logged.
   - **Expected Result**: Only commands run while LayZsh is active should be logged.

5. **Error Handling**
   - **Objective**: Ensure that errors are handled gracefully.
   - **Steps**:
     1. Simulate a scenario where the AI does not return a response.
     2. Verify that an error message is displayed.
   - **Expected Result**: An appropriate error message should be shown.

#### Automation Strategy

- **ZUnit**: Use ZUnit to write unit tests for non-interactive functions and logic.
- **Expect**: Use Expect scripts to automate the testing of interactive ZLE widgets and key bindings.

#### Example ZUnit Test

```zsh
@test "Toggle LayZsh Activation" {
  # Simulate key press to activate LayZsh
  zle -N toggle_layzsh
  bindkey '^[i^[i' toggle_layzsh
  zle toggle_layzsh

  # Check if the prompt includes the eyeball emoji
  [[ $PROMPT == *"👁️"* ]]
}

@test "Submit a Prompt as a Chat" {
  # Simulate key press to submit a chat prompt
  zle -N sgpt_zsh_chat
  bindkey '^[i^[j' sgpt_zsh_chat
  zle sgpt_zsh_chat

  # Check if a response is received
  [[ -n $BUFFER ]]
}
```

#### Conclusion

This test plan provides a structured approach to testing LayZsh's features, focusing on both interactive and non-interactive components. By using tools like ZUnit and Expect, we can automate the testing process and ensure the reliability of LayZsh's functionalities.
