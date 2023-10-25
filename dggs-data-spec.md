# Draft Specification for Data Stored in a Discrete Global Grid System

Daniel Loos, Max Planck Institute for Biogeochemistry, Jena, Germany

Date: 2023-10-25

Version: ongoing

Stage: Draft

The key words “MUST”, “MUST NOT”, “REQUIRED”, “SHALL”, “SHALL NOT”, “SHOULD”, “SHOULD NOT”, “RECOMMENDED”, “MAY”, and “OPTIONAL” in this document are to be interpreted as described in [RFC 2119](https://datatracker.ietf.org/doc/html/rfc2119).

## Preface

This specification is an early draft developed in the frame of the [Open Earth Monitor](https://earthmonitor.org/) project.
It builds on top of [OGC Topic 21](https://docs.ogc.org/as/20-040r3/20-040r3.html) i.e. [ISO 19170-1:2020](https://www.iso.org/standard/32588.html), Geographic Information — Discrete Global Grid Systems Specifications — Core Reference System and Operations, and Equal Area Earth Reference System.

Discrete Global Grid Systems (DGGS) tessellate the surface of the earth with hierarchical cells of equal area, minimizing distortion and loading time of large geospatial datasets, which is crucial in spatial statistics and building Machine Learning models.
Successful applications of DGGS include the prediction of flood events by integrating remote sensing data sets of different resolutions, as well as vector data.
Several tools were developed, mostly focusing on defining the grid and convert points from geographical space to DGGS zone ids, and vice versa.

However, no file format exist so far to store DGGS data nativeley.
This document aims to specify a suitable file format to suggest using it in further parts of [ISO 19170-1:2020](https://www.iso.org/standard/32588.html).

## DGGS

A DGGS is defined in [ISO 19170-1:2020](https://www.iso.org/standard/32588.html).

Briefly, a discrete global grid can be created using:

1. Take a platonic solid
1. Set the radius of it to those of the sphere
1. Set the rotational orientation of the solid relative to the sphere
1. Tesselate the surface of the solid using regular polygons defining the zones
1. Re-project the cell boundaries to the surface of the sphere

A DGGS is created by iterativeley creating grids at decreasing spatial resolutions.
Hereby, a parent-child relationship is defined between zones of sucessive resolutions.

To minimize distortions in terms of shape and area a DGGS:

- SHOULD be based on an icosahedron that is the platonic solid with the highest number of faces
- SHOULD be used with an projection that minimizes distortions e.g. Snyder Equal Area Projection

## Zone

A Zone is defined in [ISO 19170-1:2020](https://www.iso.org/standard/32588.html).
Briefly, zones are areas being defined by the tesselation of the polyhedron surfaces.
Each zone represents an area of the surface of the sphere.
A cell is the geometry representing the boundaries of a zone.
The tesselation MUST be unique and complete:
Each point in geographical space of the surface of the sphere must have one zone identifier.

## Zone identifier

A Zone identifier is defined in [ISO 19170-1:2020](https://www.iso.org/standard/32588.html).
Briefly, Zone identifiers are unique labels of zones.

There MAY be multiple systems of zone identifieres describing zones of the same grid, e.g., SEQNUM, PROJTRI and Q2DI for DGGRID grids, among others.

Zones with similar zone identifers MUST be nearby in geographical space.

Zone identifiers:

- MAY be tuples having multiple dimensions, e.g., DGGRID PROJTRI
- MAY encode hierarchical relatiopnship between zones at different spatial resolutions, e.g. using prefix codes in Uber H3
- MAY encode information about the angular direction to child zones (e.g. using Generalized balanced ternaries or Central Place Indexing [(Sahr 2013)](http://dx.doi.org/10.3138/cart.54.1.2018-0022)

## Zone index

A zone index is a function $I:Z \mapsto M $ mapping zone identifiers $z$ (labels) to numerical memory addresses $m$.
The zone index function MUST be bijective.

The memory adress is a n-tuple of nonnegative integers for n-dimensional zone identifiers.
It is used in positional access of elements in the data array.

An zone index defines in which order zone values are stored.
Therefore, it defines the chunking of the data and influence loading time of the values.
Zones nearby in geographical space SHOULD be also nearby in the zone index space.

There SHOULD be one preferred zone index for each zone indentifier system.
The zone index SHOULD be compact in memory space i.e. almost all numbers $m$ within $[0, \max(m)]$ SHOULD be used.

They SHOULD be continious and nearby and ...

## Data cubve

## DGGS data cubes

Different temporal resolutions CAN be created as well yielding spatiotemporal DGGS.
Is so, all temporal resolutions MUST be created for all spatial resolutions (cross product).
