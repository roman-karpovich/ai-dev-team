# Slash-normalization witnesses (CLEAN)

Leading, doubled, and trailing slashes are dropped before suffix matching; all
three resolve to `x/a/SuffixTarget.md`:
[[/a/SuffixTarget]] [[a//SuffixTarget]] [[a/SuffixTarget/]]
Zero C1 on this source.
