# A Plain Note

A plain markdown note with NO leading `--- ... ---` frontmatter at all. C3 must
skip it entirely (it is not a `type: spec` doc) without crashing on the None
frontmatter. A resolving wikilink keeps it C1-clean: [[Note]].
