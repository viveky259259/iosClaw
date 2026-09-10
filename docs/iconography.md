# iosClaw iconography

Icons describe an object, action, or state. They are not decoration and are
never borrowed from an unrelated concept merely because their shape looks
interesting.

## Rules

1. Use the semantic names in `AppIcon`; feature views do not declare SF Symbol
   strings directly.
2. Reuse a symbol only when it keeps the same meaning. For example, the
   viewfinder may represent inspection wherever inspection appears.
3. Keep objects, actions, and states distinct. An app icon is not a notification
   badge; a flow is not a lightning bolt; an audit log is not a to-do list.
4. Pair unfamiliar icons with text. Icon-only buttons are reserved for standard
   macOS actions such as Delete and include an accessible label.
5. State symbols keep stable meanings: checkmark is ready/success, triangle is
   attention, hand is a deliberate safe stop, eye is an observation, key is
   permission access, and lock-shield is protected local storage.

## Primary navigation

| Destination | Meaning | Symbol concept |
| --- | --- | --- |
| Command | Inspect the live screen | Viewfinder |
| Devices | iPhone device sources | iPhone |
| Flows | Connected automation stages | Branching flow |
| Recordings | Capture a routine | Record control |
| Audit | Local event history | Clipboard log |
| Learned context | Stored recognition knowledge | Brain |
| QA mode | Verified test plans | Checked plan stack |
| Settings | App configuration | Gear |

The automated safety suite verifies that every symbol in `AppIcon` is available
and that each navigation destination uses a distinct symbol.
