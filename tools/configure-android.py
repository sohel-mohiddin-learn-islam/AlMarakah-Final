"""CI-only debug export configuration. Never uses production signing credentials."""
import json
import os
from pathlib import Path

sdk = os.environ["ANDROID_HOME"]
java = os.environ["JAVA_HOME"]
keystore = str(Path.home() / ".android" / "debug.keystore")
settings = Path.home() / ".config/godot/editor_settings-4.4.tres"
settings.parent.mkdir(parents=True, exist_ok=True)
values = {
    "export/android/android_sdk_path": sdk,
    "export/android/java_sdk_path": java,
    "export/android/debug_keystore": keystore,
    "export/android/debug_keystore_user": "androiddebugkey",
    "export/android/debug_keystore_pass": "android",  # Standard disposable debug key.
}
settings.write_text(
    '[gd_resource type="EditorSettings" format=3]\n\n[resource]\n'
    + "\n".join(f"{key} = {json.dumps(value)}" for key, value in values.items())
    + "\n"
)
print("Configured Godot Android debug export (not Play Store signing).")
