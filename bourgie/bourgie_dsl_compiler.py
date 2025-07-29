#!/usr/bin/env python3

"""
Bourgie DSL Compiler
A Python-based compiler for YAML DSL files with file watching and hot reload.
Transforms DSL YAML files into oh-my-posh config and zsh functions.
"""

import sys
import os
import time
import json
import yaml
import argparse
import logging
import threading
from pathlib import Path
from typing import Dict, List, Optional, Any
from watchdog.observers import Observer
from watchdog.events import FileSystemEventHandler

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger('bourgie_dsl')


class DSLCompiler:
    """Main DSL compiler that transforms YAML DSL to oh-my-posh config and zsh functions."""
    
    def __init__(self):
        self.custom_functions = []
        self.compiled_config = {}
        
    def parse_dsl_file(self, dsl_file: Path) -> Dict[str, Any]:
        """Parse DSL YAML file and extract custom functions."""
        try:
            with open(dsl_file, 'r', encoding='utf-8') as f:
                dsl_data = yaml.safe_load(f)
            
            logger.info(f"Parsed DSL file: {dsl_file}")
            return dsl_data
            
        except Exception as e:
            logger.error(f"Failed to parse DSL file {dsl_file}: {e}")
            raise
    
    def extract_custom_functions(self, data: Any, path: str = "", context: Dict[str, Any] = None) -> List[Dict[str, str]]:
        """Recursively extract custom_fn definitions from YAML data."""
        functions = []
        
        if isinstance(data, dict):
            # Track segment context for better naming
            segment_context = context.copy() if context else {}
            if 'type' in data:
                segment_context['type'] = data['type']
            if 'alias' in data:
                segment_context['alias'] = data['alias']
            
            for key, value in data.items():
                current_path = f"{path}.{key}" if path else key
                
                if key == "custom_fn" and isinstance(value, str) and value.startswith("->"):
                    # Extract zsh function body (everything after ->)
                    func_body = value[2:].strip()
                    
                    # Generate function name based on segment context
                    func_name = self._generate_function_name_from_context(segment_context, path)
                    template_var = self._generate_template_variable(segment_context, path)
                    
                    functions.append({
                        'name': func_name,
                        'body': func_body,
                        'path': path,
                        'context': segment_context,
                        'template_var': template_var,
                        'env_var': func_name.upper()
                    })
                    
                    logger.debug(f"Found custom function: {func_name} -> {template_var}")
                else:
                    functions.extend(self.extract_custom_functions(value, current_path, segment_context))
                    
        elif isinstance(data, list):
            for i, item in enumerate(data):
                current_path = f"{path}[{i}]" if path else f"[{i}]"
                functions.extend(self.extract_custom_functions(item, current_path, context))
        
        return functions
    
    def _generate_function_name_from_context(self, context: Dict[str, Any], path: str) -> str:
        """Generate function name based on segment context (alias or type+alignment)."""
        if 'alias' in context and context['alias']:
            # Use alias if available (oh-my-posh's preferred identifier)
            alias = context['alias']
            safe_alias = ''.join(c for c in alias if c.isalnum() or c == '_')
            return f"_bourgie_custom_fn_{safe_alias}"
        
        elif 'type' in context:
            # Use type + alignment pattern, but include path info to ensure uniqueness
            segment_type = context['type']
            
            # Extract alignment from path if available
            alignment = "left"  # default
            if 'alignment' in context:
                alignment = context['alignment']
            elif "alignment: right" in path or "rprompt" in path:
                alignment = "right"
            
            # Add path-based suffix for uniqueness when there are multiple segments of same type
            path_suffix = ""
            if path and "[" in path:
                # Extract segment index for uniqueness
                import re
                indices = re.findall(r'\[(\d+)\]', path)
                if len(indices) >= 2:  # blocks[0].segments[1] format
                    path_suffix = f"_{indices[1]}"
            
            return f"_bourgie_custom_fn_{segment_type}_{alignment}{path_suffix}"
        
        else:
            # Fallback to path-based naming
            name = path.replace('.', '_').replace('[', '_').replace(']', '')
            name = ''.join(c for c in name if c.isalnum() or c == '_')
            return f"_bourgie_custom_fn_{name}" if name else "_bourgie_custom_fn_unnamed"
    
    def _generate_template_variable(self, context: Dict[str, Any], path: str) -> str:
        """Generate template variable name that matches the exported environment variable."""
        # Generate the function name first, then derive env var from it
        func_name = self._generate_function_name_from_context(context, path)
        env_var = f"{func_name.upper()}_OUTPUT"
        return f"{{{{ .Env.{env_var} }}}}"
    
    def remove_custom_functions(self, data: Any, functions: List[Dict[str, str]] = None, path: str = "") -> Any:
        """Remove custom_fn entries from YAML data and replace with template references."""
        if isinstance(data, dict):
            cleaned = {}
            has_custom_fn = False
            custom_fn_template = None
            
            # Check if this dict has a custom_fn
            for key, value in data.items():
                current_path = f"{path}.{key}" if path else key
                
                if key == "custom_fn":
                    has_custom_fn = True
                    # Find the corresponding function by path
                    if functions:
                        for func in functions:
                            if func['path'] == path:
                                custom_fn_template = func['template_var']
                                break
                else:
                    cleaned[key] = self.remove_custom_functions(value, functions, current_path)
            
            # If this segment had a custom_fn, add template reference
            if has_custom_fn and custom_fn_template:
                cleaned['template'] = custom_fn_template
            
            return cleaned
        elif isinstance(data, list):
            return [self.remove_custom_functions(item, functions, f"{path}[{i}]") for i, item in enumerate(data)]
        else:
            return data
    
    def _is_matching_context(self, segment_data: Dict[str, Any], func_context: Dict[str, Any]) -> bool:
        """Check if segment data matches the function context."""
        # Match by type primarily
        if 'type' in segment_data and 'type' in func_context:
            if segment_data['type'] != func_context['type']:
                return False
        
        # Match by alias if available
        if 'alias' in segment_data and 'alias' in func_context:
            return segment_data['alias'] == func_context['alias']
        
        # If no alias, match by type is sufficient for now
        return 'type' in segment_data and 'type' in func_context
    
    def generate_zsh_functions(self, functions: List[Dict[str, str]]) -> str:
        """Generate zsh file with individual functions and oh-my-posh compatible set_poshcontext."""
        if not functions:
            return self._generate_empty_zsh_file()
        
        # Generate header
        zsh_content = '''#!/usr/bin/env zsh

# Generated by Bourgie DSL Compiler
# This file contains custom prompt functions defined in the DSL
# Compatible with oh-my-posh's posh_setcontext mechanism

'''
        
        # Generate individual custom functions with proper oh-my-posh naming
        for func in functions:
            func_name = func['name']
            func_body = self._convert_to_zsh(func['body'])
            
            zsh_content += f'''# Custom function: {func_name}
# Source path: {func['path']}
# Template variable: {func['template_var']}
function {func_name}() {{
{func_body}
}}

'''
        
        # Generate set_poshcontext function that calls each individual function
        zsh_content += '''# Main context setting function - executes all custom functions
# This function is called by oh-my-posh before each prompt render
function set_poshcontext() {
'''
        
        # Add calls to all custom functions with proper environment variable export
        for func in functions:
            func_name = func['name']
            env_var_name = func['env_var']
            
            zsh_content += f'''    # Execute {func_name} and export result
    export {env_var_name}_OUTPUT="$({func_name})"
'''
        
        zsh_content += '''}

# Auto-execute set_poshcontext if not disabled
if [[ "$BOURGIE_DSL_NO_AUTO_CONTEXT" != "true" ]]; then
    set_poshcontext
fi
'''
        
        return zsh_content
    
    def _generate_empty_zsh_file(self) -> str:
        """Generate empty zsh file when no custom functions are found."""
        return '''#!/usr/bin/env zsh

# Generated by Bourgie DSL Compiler
# No custom functions found in DSL file

function set_poshcontext() {
    # No custom functions to execute
    return 0
}

# Auto-execute set_poshcontext if not disabled
if [[ "$BOURGIE_DSL_NO_AUTO_CONTEXT" != "true" ]]; then
    set_poshcontext
fi
'''
    
    def _convert_to_zsh(self, func_body: str) -> str:
        """Convert function body to proper zsh syntax with indentation."""
        lines = func_body.strip().split('\n')
        converted_lines = []
        
        for line in lines:
            # Add proper indentation
            indented_line = '    ' + line.strip()
            converted_lines.append(indented_line)
        
        return '\n'.join(converted_lines)
    
    def generate_ohmp_config(self, dsl_data: Dict[str, Any], functions: List[Dict[str, str]]) -> str:
        """Generate oh-my-posh configuration YAML."""
        # Remove custom functions from config and replace with template references
        clean_config = self.remove_custom_functions(dsl_data, functions)
        
        # Update templates to use environment variables for custom functions
        self._update_templates_for_functions(clean_config, functions)
        
        # Convert back to YAML
        yaml_content = yaml.dump(clean_config, default_flow_style=False, sort_keys=False, allow_unicode=True)
        
        # Add header comment
        header = f'''# Generated by Bourgie DSL Compiler
# Generated on: {time.strftime("%Y-%m-%d %H:%M:%S")}
# Source DSL functions: {len(functions)}

'''
        
        return header + yaml_content
    
    def _update_templates_for_functions(self, config: Any, functions: List[Dict[str, str]]) -> None:
        """Update oh-my-posh templates to reference custom function environment variables."""
        if isinstance(config, dict):
            for key, value in config.items():
                if key == "template" and isinstance(value, str):
                    # Check if this template should reference a custom function
                    for func in functions:
                        # Add environment variable reference if this segment had a custom function
                        # For now, we'll use a simple approach - segments with custom functions
                        # will get their template replaced with the environment variable
                        pass  # Template replacement logic would go here based on path matching
                else:
                    self._update_templates_for_functions(value, functions)
        elif isinstance(config, list):
            for item in config:
                self._update_templates_for_functions(item, functions)
    
    def compile_dsl(self, dsl_file: Path, output_config: Path, output_functions: Path) -> bool:
        """Compile DSL file to oh-my-posh config and zsh functions."""
        try:
            # Parse DSL file
            dsl_data = self.parse_dsl_file(dsl_file)
            
            # Extract custom functions
            functions = self.extract_custom_functions(dsl_data)
            self.custom_functions = functions
            
            logger.info(f"Extracted {len(functions)} custom functions")
            
            # Generate oh-my-posh config
            ohmp_config = self.generate_ohmp_config(dsl_data, functions)
            
            # Generate zsh functions
            zsh_functions = self.generate_zsh_functions(functions)
            
            # Write output files
            output_config.write_text(ohmp_config, encoding='utf-8')
            output_functions.write_text(zsh_functions, encoding='utf-8')
            
            # Make zsh file executable
            output_functions.chmod(0o755)
            
            logger.info(f"Compiled DSL to:")
            logger.info(f"  Config: {output_config}")
            logger.info(f"  Functions: {output_functions}")
            
            return True
            
        except Exception as e:
            logger.error(f"Compilation failed: {e}")
            return False


class DSLFileWatcher(FileSystemEventHandler):
    """File system event handler for watching DSL file changes."""
    
    def __init__(self, dsl_file: Path, compiler: DSLCompiler, output_config: Path, output_functions: Path):
        self.dsl_file = dsl_file
        self.compiler = compiler
        self.output_config = output_config
        self.output_functions = output_functions
        self.last_compilation = 0
        
    def on_modified(self, event):
        """Handle file modification events."""
        if event.is_directory:
            return
            
        # Check if the modified file is our DSL file
        if Path(event.src_path).resolve() == self.dsl_file.resolve():
            # Debounce rapid file changes
            current_time = time.time()
            if current_time - self.last_compilation < 0.5:
                return
                
            self.last_compilation = current_time
            
            logger.info(f"DSL file changed: {event.src_path}")
            
            # Recompile with a small delay to ensure file write is complete
            threading.Timer(0.1, self._recompile).start()
    
    def _recompile(self):
        """Recompile the DSL file."""
        try:
            success = self.compiler.compile_dsl(
                self.dsl_file,
                self.output_config,
                self.output_functions
            )
            
            if success:
                logger.info("✅ DSL recompilation successful")
            else:
                logger.error("❌ DSL recompilation failed")
                
        except Exception as e:
            logger.error(f"Recompilation error: {e}")


class DSLDaemon:
    """Daemon that watches DSL files and automatically recompiles them."""
    
    def __init__(self):
        self.observer = None
        self.compiler = DSLCompiler()
        self.watchers = {}
    
    def start_watching(self, dsl_file: Path, output_config: Path, output_functions: Path) -> bool:
        """Start watching a DSL file for changes."""
        try:
            if self.observer is None:
                self.observer = Observer()
                self.observer.start()
                logger.info("Started file watching daemon")
            
            # Create file watcher
            watcher = DSLFileWatcher(dsl_file, self.compiler, output_config, output_functions)
            
            # Watch the directory containing the DSL file
            watch_dir = dsl_file.parent
            self.observer.schedule(watcher, str(watch_dir), recursive=False)
            
            # Store watcher reference
            self.watchers[str(dsl_file)] = watcher
            
            logger.info(f"Started watching: {dsl_file}")
            
            # Initial compilation
            return self.compiler.compile_dsl(dsl_file, output_config, output_functions)
            
        except Exception as e:
            logger.error(f"Failed to start watching {dsl_file}: {e}")
            return False
    
    def stop_watching(self, dsl_file: Path = None):
        """Stop watching files."""
        if dsl_file:
            # Stop watching specific file
            if str(dsl_file) in self.watchers:
                del self.watchers[str(dsl_file)]
                logger.info(f"Stopped watching: {dsl_file}")
        else:
            # Stop all watching
            if self.observer:
                self.observer.stop()
                self.observer.join()
                self.observer = None
                self.watchers.clear()
                logger.info("Stopped all file watching")
    
    def is_watching(self, dsl_file: Path = None) -> bool:
        """Check if daemon is watching files."""
        if dsl_file:
            return str(dsl_file) in self.watchers
        else:
            return self.observer is not None and self.observer.is_alive()


def create_status_file(status_file: Path, daemon: DSLDaemon, dsl_file: Path, pid: int):
    """Create status file with daemon information."""
    status_data = {
        'pid': pid,
        'dsl_file': str(dsl_file),
        'started': time.time(),
        'status': 'running' if daemon.is_watching(dsl_file) else 'stopped'
    }
    
    with open(status_file, 'w') as f:
        json.dump(status_data, f, indent=2)


def main():
    """Main entry point for the DSL compiler."""
    parser = argparse.ArgumentParser(description='Bourgie DSL Compiler')
    parser.add_argument('command', choices=['compile', 'watch', 'daemon'], 
                       help='Command to execute')
    parser.add_argument('dsl_file', help='Path to DSL YAML file')
    parser.add_argument('--config-output', '-c', 
                       help='Output path for oh-my-posh config (default: <dsl_file>-compiled.yaml)')
    parser.add_argument('--functions-output', '-f',
                       help='Output path for zsh functions (default: <dsl_file>-functions.zsh)')
    parser.add_argument('--daemon-pid-file', '-p',
                       help='PID file for daemon mode')
    parser.add_argument('--verbose', '-v', action='store_true',
                       help='Enable verbose logging')
    
    args = parser.parse_args()
    
    if args.verbose:
        logging.getLogger().setLevel(logging.DEBUG)
    
    # Setup paths
    dsl_file = Path(args.dsl_file).resolve()
    
    if not dsl_file.exists():
        logger.error(f"DSL file not found: {dsl_file}")
        return 1
    
    # Default output paths
    if args.config_output:
        config_output = Path(args.config_output)
    else:
        config_output = dsl_file.with_name(dsl_file.stem + '-compiled.yaml')
    
    if args.functions_output:
        functions_output = Path(args.functions_output)
    else:
        functions_output = dsl_file.with_name(dsl_file.stem + '-functions.zsh')
    
    # Execute command
    if args.command == 'compile':
        # One-time compilation
        compiler = DSLCompiler()
        success = compiler.compile_dsl(dsl_file, config_output, functions_output)
        return 0 if success else 1
        
    elif args.command == 'watch':
        # Watch mode (foreground)
        daemon = DSLDaemon()
        
        try:
            success = daemon.start_watching(dsl_file, config_output, functions_output)
            if not success:
                return 1
            
            logger.info("Watching for changes... Press Ctrl+C to stop")
            
            # Keep running until interrupted
            while True:
                time.sleep(1)
                
        except KeyboardInterrupt:
            logger.info("Stopping file watcher...")
            daemon.stop_watching()
            return 0
        except Exception as e:
            logger.error(f"Watch mode error: {e}")
            return 1
            
    elif args.command == 'daemon':
        # Daemon mode (background)
        daemon = DSLDaemon()
        
        # Create PID file if specified
        if args.daemon_pid_file:
            pid_file = Path(args.daemon_pid_file)
            pid_file.write_text(str(os.getpid()))
            create_status_file(pid_file.with_suffix('.status'), daemon, dsl_file, os.getpid())
        
        try:
            success = daemon.start_watching(dsl_file, config_output, functions_output)
            if not success:
                return 1
            
            logger.info(f"Daemon started (PID: {os.getpid()})")
            
            # Keep running
            while True:
                time.sleep(10)
                
        except KeyboardInterrupt:
            logger.info("Daemon stopping...")
            daemon.stop_watching()
            
            # Clean up PID file
            if args.daemon_pid_file:
                try:
                    Path(args.daemon_pid_file).unlink(missing_ok=True)
                    Path(args.daemon_pid_file).with_suffix('.status').unlink(missing_ok=True)
                except:
                    pass
            
            return 0
        except Exception as e:
            logger.error(f"Daemon error: {e}")
            return 1


if __name__ == '__main__':
    sys.exit(main())