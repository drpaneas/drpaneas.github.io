+++
date = "2014-10-02"
title = "Example of rst"
description = "Some basic stuff for writing blogposts"
menu = "How-To"
+++

.. code-block:: bash

  +++
  date = "YYYY-MM-DD"
  title = "Write a titles"
  description = "Write a description"
  menu = "How-To"
  +++



for writing code use:

.. code-block:: bash

  .. code-block:: bash

    bash code
    ....
    ....


Test the rst syntax with:

.. code-block:: bash

   rst2html5 file.rst --strict


but first, mark the Hugo metadata as comments, otherwise the validator
is going to complain about them. 


For images use this:

.. code-block:: bash

  .. image:: ../images/image.png


and for links:

.. code-block:: bash

  `Panos Georgiadis`_
  ...
  ...
  .. _Panos Georgiadis: mailto:pgeorgiadis@suse.de


for table of contents:

.. code-block:: bash

  .. contents:: Table of Contents
      :depth: 3


