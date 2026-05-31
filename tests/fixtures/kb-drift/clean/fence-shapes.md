# Fence Shapes — tilde and longer-backtick fences

A tilde-delimited fence is still a code block — `[[x]]` inside is not a link:

~~~
a tilde-fenced [[x]] is not a rendered wikilink
~~~

A longer-backtick fence wraps a shorter run verbatim — the inner triple and
the `[[x]]` it surrounds are both inside the outer fence, so zero C1:

````
```
an inner [[x]] inside a longer-backtick fence is not a link
```
````
