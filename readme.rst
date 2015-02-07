########################
RST Quick Start Tutorial
########################

:Authors: Panos Georgiadis
:date: 2015-02-06
:Title: First
:Version: 1.0 of 2015-02-06


Overview
========

Here's a list of plugins we are going to install and configure

1. Vundle            - https://github.com/gmarik/Vundle.vim
2. RIV               - https://github.com/Rykka/riv.vim
3. InstantRST        - https://github.com/Rykka/InstantRst
4. InstantRST Server - https://github.com/rykka/instantrst.py
5. Rhythm css        - https://github.com/Rykka/rhythm.css
6. NerdTREE          - https://github.com/scrooloose/nerdtree
7. PowerLine         - https://github.com/powerline/powerline
8. ctrlp             - http://kien.github.io/ctrlp.vim/
9. tabular           - https://github.com/godlygeek/tabular

:Note: Note that this will replace your `.vimrc` file
       so in case you need your old configuration
       please make sure you have a backup.

Installation
------------
I use **Vundle** as the tool that helps me to install all the plugins I need
in a very simple way.

1. **Requirements SLE-12**

.. code-block:: bash

   sudo zypper install python-devel curl git python-pip python-docutils
   sudo pip install instant-rst

:Tip: I would be better if you create a *virtualenv* rather than installing
      pip stuff globally.

2. **Installation**

   Just copy and paste the following command in your terminal
   and it will do all the work for you.

.. code-block:: bash

   curl http://bit.ly/1DCKEn6 -L -o - | sh


Configuration
-------------
You can do all your configuration in `~/.vimrc` file

Themes
~~~~~~
By default `wombat256mod` is enabled, which is a *dark* theme.
If you prefer white background, go to ``~/.vimrc`` and change
the from ``color wombat256mod`` to ``color proton``.

More themes can be found at
https://github.com/flazz/vim-colorschemes/tree/master/colors
while you can put them into ``~/.vim/colors/`` folder and later
enable them via your ``~/.vimrc`` file.

Instant Preview
---------------
The InstantRST plugin allows you to write `RST` and preview in on the fly using
your browser. The good thing is that it also catches potential errors
on real time. *For example*:

:example:
    1. Open the server ``instantRst -f <yourfile>.rst``
    2. From another terminal, open the file with vim ``vim <yourfile.rst``
    3. Type ``:InstantRst!`` in vim normal mode

Basic notation
~~~~~~~~~~~~~~

+ **Bold** = ``**Strong**`` *e.g.* **this text is bold**
+ **Italic** = ``*Italic*`` *e.g.* *this text is italic*
+ **Inline Code** = ````some code```` *e.g.* ``$this`` variable
+ **Link** = ``http://suse.com/`` *e.g.* http://suse.com/
+ **Hyperlink** = ```Bugzilla <https://www.bugzilla.org/>`_`` *e.g* `Bugzilla
  <https://www.bugzilla.org/>`_

Header
~~~~~~

Many times we need to structure our document using some kind of section
similar to HTML Headers. If you are not sure what kind of character
corresponds to each header (from 1 to 6), you can use ``:RivTitle[1-6]``
or `ctrl+e` + `s[1-6]` to create a level title.

Level 1
=======

Level 2
-------

Level 3
~~~~~~~

Level 4
"""""""

Level 5
'''''''

Level 6
```````

Code Highlighting
~~~~~~~~~~~~~~~~~

For the ``code`` directives (also ``sourcecode`` and ``code-block``).
Syntax highlighting of Specified languages are on.

*e.g.*

.. code:: bash

   .. code:: bash

       #!\bin\bash
       echo "The date is $(date)"

is going to be generated into:

.. code:: bash

 #/bin/bash
 echo "The date is $(date)"


Tables
~~~~~~
It's very easy to create table and you should use this functionality. There are
two way to create a table using.

Normal Mode
"""""""""""
Type: ``:RivTableCreate`` or ``ctrl+e`` + ``tc``

and it will ask you:
    - Input row number of table: 2
    - Input column number of table: 4

and it will automatically generate a table:

+---------+----------+------+----------+
|      34 | 2        |  sdf | sdf      |
+---------+----------+------+----------+
| sdfddf  | dfsdfsdf | dd   | dfsdfsdf |
+---------+----------+------+----------+

Insert Mode
"""""""""""
In *Insert Mode* you are building by hand. Just write something like:

.. code:: bash

   +--+

and press ``Enter`` to create a new line:

.. code:: bash

   +--+
   |  |
   |  |
   |  |
   +--+

and press ``|`` + ``Enter`` in order to create a new column

.. code:: bash

   +--+--+
   |  |  |
   |  |  |
   |  |  |
   +--+--+

then press ``ctrl+c`` + ``Enter`` in order to move your cursor to the last
left corner of the table. Then go into `Insert` mode and press
``Enter`` to create a new row:

.. code:: bash

   +--+--+
   |  |  |
   |  |  |
   |  |  |
   |  |  |
   +--+--+
   |  |  |
   +--+--+



:Notice: After you have finished writing inside the cells, remember to **use
         intendetation** by pressing either ``<`` or ``>`` keys.
         In that way, your table's **structure** will be **auto-fixed**
         by shifting the cells to their content properly.


Links
~~~~~~
This is how you can create links. Just type ``:RivCreateLink`` or `ctrl+c` + `ck`
and it will ask you for two things: name of the link and the URL of the link:

- `Input link name:` <type 'suse' and press <Enter>

  - `suse`: <type 'suse.com' and press <Enter>

and then, the plugin will automatically create this code:

.. code:: bash

   suse_

   .. _suse: suse.com # placed in the end of the file

So, in that way you can have you links, and they will look like that: suse_



Tricks in RIV Plugin
~~~~~~~~~~~~~~~~~~~~

+ **Date** ``:RivCreateDate`` or ``ctrl + e`` + ``cdd``
+ **Table of Contents** ``:RivCreateContent`` or ``ctrl+e`` + ``cc``
+ **View sections** ``:RivHelpSection`` or `ctrl+e` + `hs`
+ **Select 2 lines** `V` + `j` 
+ **Select 3 lines** `V` + `j` + `j` and you can indent using ``<`` or ``>``

Export in formats
~~~~~~~~~~~~~~~~~
You can export your RST document while you are working on it. The only thing
you have to do is to decide in what format you want to save your file as.

+ ``:Riv2HtmlAndBrowse`` or `ctrl+e` + `2hh` html file.
+ ``:Riv2Odt`` or `ctrl+e` + `2oo` to convert to odt file.
+ ``:Riv2Xml`` or `ctrl+e` + `2xx` to convert to xml file.
+ ``:Riv2Latex`` or `ctrl+e` + `2ss` to convert to latex file.
+ ``:Riv2Pdf`` or `ctrl+e` + `2pp` to convert to pdf file.

NERDTree Plugin
~~~~~~~~~~~~~~~
Enable it by typing: `ctrl+f` or ``:NERDTreeToggle`` or just ``:NERDTree``.
Once it has been enabled thenm you will see the directory structure of your
computer in the left of the terminal. To disable it, type `q`.

+ **Toggle NERDTree**
  
  + Open  : ``ctrl+f``
  + Close : ``q``

+ **Edit Files**
  
  + *Open the file in the right window*: ``o`` or preview ``go``
  + *Open the file by splitting the window vertically*: ``s`` or preview ``gs``
  + *Open the file by splitting the window horizontally*: ``i`` or preview ``gi``
  + *Open the file in a new tab and go to that tab*: ``t``
  + *Open the file in a new tab, but don't go there yet*: ``T``

Speaking of splitting and tabbing, I have made special configuration based on
PyCon 2012 Talk. All the changes are into the `~/.vimrc` file.

**Split Navigation**

+ Hold down ``ctrl`` and press repeatidly ``w``. As a result, your cursor will
  move from one split screen to another. It doesn't matter if you have 2
  splitted screens or more. Well, if you have just 2, then each quite handy.
  For example, this is how I switch between the `NERDTree` and the open file on
  the right.

  Otherwise, if you have splitted your screen on 4 or 6 parts, feel free to use
  the standard VIM navigation:

  - ``ctrl + w`` and ``h`` for left
  - ``ctrl + w`` and ``l`` for right
  - ``ctrl + w`` and ``j`` for down
  - ``ctrl + w`` and ``k`` for up

+ **Tab Navigation**

  - *move to the left tab*: ``,`` + ``n``
  - *move to the right tab*: ``,`` + ``m``
  - *open new tab on the right*: ``,`` + ``b``
  - *close current tab*: ``,`` + ``e`` or ``E``
  - *save the current tab*: ``ctrl`` + ``z``

+ **Bookmarks**

It's a neat feature, since you can quickly go to the folder you want. Some bookmarks of mine would be the HOME directory and others which I usually have my scripts or downloads or my git repositories. In order to create a bookmark, go to the folder you
want to book and type  ``:Bookmark <name-of-the-bookmark>``. Then, everytime
you want to see all your bookmark, just type: ``B``.

+ **Change Working Directory**

Sometimes, while I work on a particular repository I usually get lost among
other files I open in the process. So, instead of going again (and again)
back to same repo, I can simply *mark* it the `pwd`. Go to the folder you want
to mark as pwd and press ``cd``. After that, change directory, go wherever you
want and go back to your pwd by just pressing ``C``.


CtrlP Plugin
~~~~~~~~~~~~
Enable it by typing: `ctrl+p` or ``:CtrlP``

Tabularize Plugin
~~~~~~~~~~~~~~~~~
Select the lines in Visual Mode (``Vj``) and the press color ``:``. There
you will see something like: ``'<,'>`` so, next to that you can call Tabularize
plugin by typing ``Tabularize /{pattern}``. It will looks like:

.. code:: bash

   '<,'>Tabularize /{pattern}


.. _suse: suse.com
