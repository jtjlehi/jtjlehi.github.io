---
layout: page
---

Welcome to my blog.

Don't expect to much from it. Especially in the way of grammer.

I'm currently working full time writing Rust, Haskell, and Cuda kernels. I also do a lot of programming in my spare time (mostly in the languages listed above).

## Posts

<ul>
  {% for post in site.posts %}
    <li>
      <a href="{{ post.url }}">{{ post.title }}</a>
    </li>
  {% endfor %}
</ul>
