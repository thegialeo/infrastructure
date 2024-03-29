Quickstart
==================================================

Description
--------------------------------------------------
The openrouteservice library gives you painless access to the openrouteservice_ (ORS) routing API's.
It performs requests against our API's for 

- directions_
- `reverse geocoding`_
- isochrones_
- `matrix routing calculations`_

For further details, please visit:

- homepage_
- documentation_

By using this library, you agree to the ORS `terms and conditions`_.

.. _openrouteservice: https://go.openrouteservice.org
.. _homepage: https://go.openrouteservice.org
.. _documentation: https://go.openrouteservice.org/documentation/
.. _directions: https://go.openrouteservice.org/documentation/#/reference/directions/directions/directions-service
.. _isochrones: https://go.openrouteservice.org/documentation/#/reference/isochrones/isochrones/isochrones-service
.. _`reverse geocoding`: https://go.openrouteservice.org/documentation/#/reference/geocoding/geocoding/geocoding-service
.. _`matrix routing calculations`: https://go.openrouteservice.org/documentation/#/reference/matrix/matrix/matrix-service-(post)
.. _`terms and conditions`: https://go.openrouteservice.org/terms-of-service/

Requirements
-----------------------------
openrouteservice requires:

- Python >= 2.7, 3.4, 3.5, 3.6
- ``requests`` library

unit testing requires additionally the following Python libraries:

- ``nose``
- ``responses``
- ``mock``

Installation
------------------------------
To install from PyPI, simply use pip::
	
	pip install openrouteservice

To install the latest and greatest from source::

   	pip install git+git://github.com/xxx

For ``conda`` users, you can install using ``setuptools`` (required Python package)::

	git clone https://github.com/GIScience/
	python setup.py install

This command will install the library to your PYTHONPATH. Also works in virtual environments.


Testing
---------------------------------
If you want to run the unit tests, see Requirements_. ``cd`` to the library directory and run::

	nosetests -v

``-v`` flag for verbose output (recommended).


Usage
---------------------------------
Basic example
^^^^^^^^^^^^^^^^^^^^

.. code:: python

	import openrouteservice

	coords = ((8.34234,48.23424),(8.34423,48.26424))

	client = openrouteservice.Client(key='') # Specify your personal API key
	routes = client.directions(coords)

	print routes

For convenience, all request performing module methods are wrapped inside the ``client`` class. This has the
disadvantage, that your IDE can't auto-show all positional and optional arguments for the 
different methods. And there are a lot!

The slightly more verbose alternative, preserving your IDE's smart functions, is::
	
	import openrouteservice
	from openrouteservice.directions import directions

	coords = ((8.34234,48.23424),(8.34423,48.26424))

	client = openrouteservice.Client(key='') # Specify your personal API key
	routes = directions(client, coords)


Decode Polyline
^^^^^^^^^^^^^^^^^^^^^^^^^^
By default, the directions API returns `encoded polylines <https://developers.google.com/maps/documentation/utilities/polylinealgorithm>`_.
To decode to a ``dict``, which is GeoJSON-ready, simply do::

	import openrouteservice
	from openrouteservice import convert

	coords = ((8.34234,48.23424),(8.34423,48.26424))

	client = openrouteservice.Client(key='') # Specify your personal API key

	# decode_polyline needs the geometry only
	geometry = client.directions(coords)['routes'][0]['geometry']

	decoded = convert.decode_polyline(geometry)

	print decoded


Local ORS instance
^^^^^^^^^^^^^^^^^^^^
If you're hosting your own ORS instance, you can alter the ``base_url`` parameter to fit your own::
	
	import openrouteservice

	coords = ((8.34234,48.23424),(8.34423,48.26424))

	# key can be omitted for local host
	client = openrouteservice.Client(key='',
	                                 base_url='https://foo/bar') 

	# url is the extension for your endpoint, no trailing slashes!
	# params has to be passed explicitly, refer to API reference for details
	routes = client.request(url='/directions',
	                        params={'coordinates': coords,
	                                'profile': 'driving-hgv'
	                               }
	                        )

Support
--------

For general support, contact `Google Groups`_.

For issues/bugs/enhancement suggestions, please use https://github.com/GIScience.


.. _`Google Groups`: https://groups.google.com/forum/?utm_source=digest&utm_medium=email#!forum/openrouteservice