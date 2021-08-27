# Write Good Code

What makes good code good? I’m glad you asked. A nice little article by the late [Paul DiLascia](http://en.wikipedia.org/wiki/Paul_Dilascia) sums it up nicely. Read it at:

http://msdn.microsoft.com/en-us/magazine/cc163962.aspx

In short, “all good programming exhibits the same time-honored qualities: **simplicity**, **readability**, **modularity**, **layering**, **design**, **efficiency**, **elegance**, and **clarity**.” And the occasional clever hack...

* [Write Simple Code](#write-simple-code)
* [Write Readable Code](#write-readable-code)
* [Write Modular Code](#write-modular-code)
* [Write Layered Code](#write-layered-code)
* [Write Designed Code](#write-designed-code)
* [Write Efficient Code](#write-efficient-code)
* [Write Elegant Code](#write-elegant-code)
* [Write Clear Code](#write-clear-code)
* [Use Clever Hacks Sparingly](#use-clever-hacks-sparingly)

[“Uncle” Bob Martin](http://butunclebob.com/), author of [Clean Code](http://www.amazon.com/Clean-Code-Handbook-Software-Craftsmanship/dp/0132350882/) and [Agile Principles, Patterns, and Practices in C#](http://www.amazon.com/Agile-Principles-Patterns-Practices-C/dp/0131857258/), recommends writing [SOLID](http://www.lostechies.com/blogs/chad_myers/archive/2008/03/07/pablo-s-topic-of-the-month-march-solid-principles.aspx) code:

* **S**ingle Responsibility Principle— [PDF](https://drive.google.com/file/d/0ByOwmqah_nuGNHEtcU5OekdDMkk/view)
* **O**pen/Closed Principle— [PDF](https://drive.google.com/file/d/0BwhCYaYDn8EgN2M5MTkwM2EtNWFkZC00ZTI3LWFjZTUtNTFhZGZiYmUzODc1/view)
* **L**iskov Substitution Principle— [PDF](https://drive.google.com/file/d/0BwhCYaYDn8EgNzAzZjA5ZmItNjU3NS00MzQ5LTkwYjMtMDJhNDU5ZTM0MTlh/view)
* **I**nterface Segregation Principle— [PDF](https://drive.google.com/file/d/0BwhCYaYDn8EgOTViYjJhYzMtMzYxMC00MzFjLWJjMzYtOGJiMDc5N2JkYmJi/view)
* **D**ependency Injection Principle— [PDF](https://drive.google.com/file/d/0BwhCYaYDn8EgMjdlMWIzNGUtZTQ0NC00ZjQ5LTkwYzQtZjRhMDRlNTQ3ZGMz/view)

See also [Dimecast SOLID videos](https://www.youtube.com/playlist?list=PLbJwoU-LyMclDU2ZFgwdVfu24XwKkP4g4).


## Write Simple Code

**Simplicity** means you don’t do in ten lines what you can do in five. It means you make extra effort to be concise, but not to the point of obfuscation. It means you abhor open coding and functions that span pages. Simplicity—of organization, implementation, design—makes your code more reliable and bug free. There’s less to go wrong.

— Paul DiLascia


## Write Readable Code

**Readability** means what it says: that others can read your code. Readability means you bother to write comments, to follow conventions, and pause to name your variables wisely. Like choosing “taxrate” instead of “tr”.

— Paul DiLascia


## Write Modular Code

**Modularity** means your program is built like the universe. The world is made of molecules, which are made of atoms, electrons, nucleons, quarks, and (if you believe in them) strings. Likewise, good programs erect large systems from smaller ones, which are built from even smaller building blocks. You can write a text editor with three primitives: move, insert, and delete. And just as atoms combine in novel ways, software components should be reusable.

— Paul DiLascia

Note: A good guideline to remember here is the object-oriented design practice to “favor composition over inheritance.”


## Write Layered Code

**Layering** means that internally, your program resembles a layer cake. The app sits on the framework sits on the OS sits on the hardware. Even within your app, you need layers, like file-document-view-frame. Higher layers call ones below, which raise events back up. (Calls go down; events go up.) Lower layers should never know what higher ones are up to. The essence of an event/callback is to provide blind upward notification. If your doc calls the frame directly, something stinks. Modules and layers are defined by APIs, which delineate their boundaries. Thus, design is critical.

— Paul DiLascia

[Jeffrey Pallermo](http://jeffreypalermo.com/) proposed a slightly different view on the traditional layered architecture called the [“onion” architecture](http://jeffreypalermo.com/blog/the-onion-architecture-part-1/). Instead of viewing an architecture like a wedding cake, view it like an onion, with core dependencies deeper inside and working outward to the more infrastructural dependencies such as data and file access, tests, and user interfaces. Jeffrey [presented the onion architecture](http://jeffreypalermo.com/blog/architecture-analysis-onion-architecture-webcast/) for the [International Association of Software Architects](http://www.iasahome.org/web/home/home) in 2010.


## Write Designed Code

**Design** means you take time to plan your program before you build it. Thoughts are cheaper than debugging. A good rule of thumb is to spend half your time on design. You need a functional spec (what the programs does) and an internal blueprint. APIs should be codified in writing.

— Paul DiLascia

## Write Efficient Code

**Efficiency** means your program is fast and economical. It doesn’t hog files, data connections, or anything else. It does what it should, but no more. It loads and departs without fuss. At the function level, you can always optimize later, during testing. But at high levels, you must plan for performance. If the design requires a million trips to the server, expect a dog.

— Paul DiLascia


## Write Elegant Code

**Elegance** is like beauty: hard to describe but easy to recognize. Elegance combines simplicity, efficiency, and brilliance, and produces a feeling of pride. Elegance is when you replace a procedure with a table, or realize that you can use recursion—which is almost always elegant.

— Paul DiLascia


## Write Clear Code

**Clarity** is the granddaddy of good programming, the platinum quality all the others serve. Computers make it possible to create systems that are vastly more complex than physical machines. The fundamental challenge of programming is managing complexity. Simplicity, readability, modularity, layering, design, efficiency, and elegance are all time-honored ways to achieve clarity, which is the antidote to complexity.

Clarity of code. Clarity of design. Clarity of purpose. You must understand—really understand—what you’re doing at every level. Otherwise you’re lost. Bad programs are less often a failure of coding skill than of having a clear goal. That’s why design is key. It keeps you honest. If you can’t write it down, if you can’t explain it to others, you don’t really know what you’re doing.

— Paul DiLascia


## Use Clever Hacks Sparingly

There’s so much I’ve left out, but there’s one more thing I hesitate to add. Use it sparingly and only in desperation: the clever hack. The clever hack is when you sacrifice your principles to expedience. When you hardcode some condition or make a call up the layer cake—or commit some other embarrassment—because it works and there’s no time to do it right. But remember: it must be clever! It’s the cleverness that redeems the hack and gives it a kind of perverse elegance. And if the hack doesn’t work, don’t blame me! Happy programming!

— Paul DiLascia
