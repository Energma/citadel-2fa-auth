# Salvage

`category_icon_picker.dart` is the surviving piece of the group category-icon
feature. The rest of that work (TokenGroup.icon, the schema v4 migration, the
ServiceIcon.styleFor/knownServices refactor, and its tests) was lost before it
was committed and must be redone.

The picker is parked here rather than in lib/ because it references
`ServiceIcon.styleFor` and `ServiceIcon.knownServices`, which do not exist on
the current `service_icon.dart`. Move it back once that API is restored.
