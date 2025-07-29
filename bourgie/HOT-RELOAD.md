# 🔥 Bourgie Hot Reload Feature

The hot reload feature allows you to edit your oh-my-posh configuration file and see changes immediately without opening a new terminal or reloading your shell. This is perfect for theme development and testing.

## How It Works

Instead of running oh-my-posh once during shell initialization, hot reload mode runs oh-my-posh fresh for each prompt, reading the configuration file every time. This is achieved by:

1. **Subshell Execution** - Each prompt runs `oh-my-posh print` in a clean subshell
2. **Fresh Config Loading** - Configuration is read from disk on every prompt
3. **Environment Preservation** - Current environment variables are passed to the subshell
4. **Fallback Handling** - If config parsing fails, a fallback prompt is shown

## Usage

### Enable Hot Reload

```bash
# Via command line
bourgie_hot_reload on

# Via configuration command
bourgie_config hot-reload on

# Via interactive wizard
bourgie_config
# Choose option [5] Configure Hot Reload
```

### Disable Hot Reload

```bash
# Via command line
bourgie_hot_reload off

# Via configuration command  
bourgie_config hot-reload off
```

### Check Status

```bash
bourgie_hot_reload status
```

### Performance Benchmarking

```bash
bourgie_hot_reload_benchmark
```

## Development Workflow

1. **Enable hot reload** in your development terminal:
   ```bash
   bourgie_hot_reload on
   ```

2. **Open your config file** in your favorite editor:
   ```bash
   code $BOURGIE_CONFIG_FILE
   # or
   vim ~/.zgenom/sources/brandon-fryslie/rad-plugins/___/bourgie/posh-config.yaml
   ```

3. **Make changes** to colors, segments, templates, etc.

4. **Save the file** - changes appear immediately in your prompt!

5. **Iterate quickly** - no need to reload shell or open new terminals

## Performance Impact

Hot reload adds a small performance overhead:

- **Typical impact**: 50-100ms per prompt
- **Depends on**: Config complexity, system performance, disk speed
- **Benchmark tool**: Use `bourgie_hot_reload_benchmark` to measure

### Sample Benchmark Results

```
🔥 Benchmarking hot reload performance...
Running 10 prompt generations...
  Iteration 1: 0.067s
  Iteration 2: 0.052s
  Iteration 3: 0.048s
  Iteration 4: 0.051s
  Iteration 5: 0.049s
  Iteration 6: 0.053s
  Iteration 7: 0.047s
  Iteration 8: 0.050s
  Iteration 9: 0.048s
  Iteration 10: 0.052s

📊 Results:
  Total time: 0.517s
  Average time per prompt: 0.052s
  Iterations: 10
```

## Error Handling

Hot reload includes robust error handling:

### Config File Missing
If the config file is deleted or moved:
```
bourgie-error> 
```

### Invalid YAML Syntax  
If the config has syntax errors:
```
bourgie-reload>
```

### oh-my-posh Errors
If oh-my-posh fails to parse the config:
```
bourgie-reload>
```

## Debug Mode

Enable debug logging to see hot reload performance:

```bash
bourgie_config debug on
bourgie_hot_reload on

# Check the debug log
tail -f /tmp/bourgie-debug.log
```

Debug output includes:
```
[2025-07-29 10:15:32] [BOURGIE DEBUG] Hot reload prompt generation took: 0.052s
[2025-07-29 10:15:35] [BOURGIE DEBUG] Hot reload prompt generation took: 0.048s
```

## Environment Variables

Hot reload preserves these environment variables in the subshell:

- `GITTACULOUS_ENABLE_SSH_THEME`
- `ENABLE_DOCKER_PROMPT`
- `ENABLE_NODE_PROMPT`
- `LAZY_NODE_PROMPT`
- `BOURGIE_SHOW_TIME`
- `RAD_BOURGIE_DEBUG`
- `USER`
- `HOSTNAME`
- `NVM_LOADED`

## Tips & Best Practices

### 🎯 **For Theme Development**
- Keep hot reload enabled during active development
- Use debug mode to track performance
- Test with both simple and complex configurations

### ⚡ **For Performance**
- Disable hot reload in production/daily use
- Use `bourgie_hot_reload toggle` for quick on/off switching
- Monitor performance with benchmark tool

### 🐛 **For Troubleshooting**
- Enable debug logging: `bourgie_config debug on`
- Check config syntax: `oh-my-posh print primary --config yourconfig.yaml`
- Use fallback prompts to identify config issues

### 📝 **For Config Editing**
- Save frequently to see incremental changes
- Use syntax highlighting for YAML files
- Keep backup copies of working configurations

## Comparison: Hot Reload vs Standard Mode

| Feature | Standard Mode | Hot Reload Mode |
|---------|---------------|-----------------|
| **Config Loading** | Once at shell startup | Every prompt |
| **Change Detection** | Manual reload required | Automatic |
| **Performance** | Fast (~1-5ms) | Slower (~50-100ms) |
| **Development** | Requires new terminals | Immediate feedback |
| **Production Use** | ✅ Recommended | ❌ Not recommended |
| **Resource Usage** | Low | Medium |

## Integration with Other Features

### DSL Support
Hot reload works with both:
- Standard YAML configs
- DSL-generated configs (auto-recompiled)

### Interactive Wizard
Hot reload is integrated into the configuration wizard:
```bash
bourgie_config
# Option [5] Configure Hot Reload
```

### Debug Logging
Hot reload respects debug settings and logs performance metrics when enabled.

## Troubleshooting

### Slow Performance
```bash
# Check if hot reload is the cause
bourgie_hot_reload_benchmark

# If too slow, disable hot reload
bourgie_hot_reload off
```

### Config Not Updating
```bash
# Verify hot reload is enabled
bourgie_hot_reload status

# Check config file path
echo $BOURGIE_CONFIG_FILE

# Verify file exists and is readable
ls -la $BOURGIE_CONFIG_FILE
```

### Prompt Errors
```bash
# Enable debug logging
bourgie_config debug on

# Check for config syntax errors
oh-my-posh print primary --config $BOURGIE_CONFIG_FILE

# View debug output
tail -f /tmp/bourgie-debug.log
```

---

The hot reload feature transforms oh-my-posh theme development from a slow, iterative process into a fast, interactive experience. Enable it during development, disable it for daily use, and enjoy the best of both worlds!