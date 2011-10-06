HTTP
====

Ruby has always been this extremely web-focused language, and yet despite the
selection of HTTP libraries out there, I always find myself falling back on
Net::HTTP, and Net::HTTP sucks.

Ruby should be simple and elegant and beautiful. Net::HTTP is not. I've often
found myself falling back on the Perlish horrors of open-uri just because I
found Net::HTTP to be too much of a pain. This shouldn't be!

HTTP should be simple and easy! It should be so straightforward it makes
you happy with how delightful it is to use!

API
---

Let's start with getting things:

    Http.get "http://www.google.com"

That's it! The result is the response body.

Don't like "Http"? No worries, this works as well:

    HTTP.get "http://www.google.com"

After all, There Is More Than One Way To Do It!
