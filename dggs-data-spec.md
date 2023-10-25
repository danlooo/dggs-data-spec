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

Cells MUST be the same polygons whenever possible. For example, tesselations of the surface of a icosahedron with hexagons requires to add 12 pentagons.

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

A zone index is a bijective function $I:Z \mapsto M $ mapping all zone identifiers $z \in Z$ (labels) to unique numerical memory addresses $m \in M$.
The memory adress is a n-tuple of nonnegative integers for n-dimensional zone identifiers.
It is used in positional access of elements in the data array.
An zone index defines in which order zone values are stored.
Therefore, it defines the chunking of the data and influence loading time of the values.

- Zones with similar memory addresses MUST be nearby in geographical space.
- There SHOULD be one preferred zone index for each zone indentifier system.
- Zone indicies SHOULD be compact in memory space i.e. almost all numbers $m$ within $[0, \max(m)]$ SHOULD be used. Space filling curves MAY be used here (e.g. Hilbert curve like index in Google S2)

![Net of an icosahedron](assets/icosahedron-net.png)
**Figure 1**: Merging 2 faces of a polyhedron to one rectangular chart [(Mahdavi-Amiri et al. 2014)](http://dx.doi.org/10.1080/17538947.2014.927597).

Memory addresses created by the zone index MUST describe rectangular grids.
This is just a vector for 1D zone identifieres.
Moreover, zone identifiers MAY describe zones as their position on the face of a polyhedron (e.g. DGGRID PROJTRI).
Hereby, the surface of the polyhedron is subdivided in charts that are as rectangular as possible (See Figure 1).
This allows to store DGGS data in n-dimensional arrays.

# TODO

Geotransforms?
https://gdal.org/tutorials/geotransforms_tut.html
external calls

## DGGS Data Cube

A (regular) DGGS data cube is an n-dimensional array to store values of variables across the globe.
The values are arranged on a selected grid and zone index.

There MUST be at least all spatial dimensions present needed for the selected zone identifier.
Values MUST be sampled in accordance to the selected grid.
DGGS data cubes are regular, i.e. there MUST NOT be missing values within the global bounding box.
Values MAY be interpolated.

## DGGS Pyramid

A DGGS data cube pyramid is a collection of DGGS data cubes.
The only difference of those DGGS data cubes is that they have at meast different spatial resolutiosn.
Different temporal resolutions MAY be created as well yielding spatiotemporal DGGS.
Is so, all temporal resolutions MUST be created for all spatial resolutions (cross product).

## DGGS Data Model

```plantuml
@startuml
!define COMMENT(x) <color:grey>x</color>

enum Polyhedron {
    tetrahedron
    cube
    octahedron
    dodecahedron
    icosahedron
}

enum Polygon {
    triangle
    quadliteral
    pentagon
    hexagon
}

abstract Transformation {
    COMMENT(Calculate geographical coordinates from indicies)
    --
    name: string
}


entity LinearTransformation {
    COMMENT(Like GDAL geotransform)
    GT0: float
    GT1: float
    GT2: float
    GT3: float
    GT4: float
    GT5: float
}

LinearTransformation <|-- Transformation

entity ExternalTransformation {
    COMMENT(External shell call)
    command: string
    --
    name: string
}

ExternalTransformation <|-- Transformation

entity GridSystem {
    COMMENT(Recipe to generate spatial grids)
    polyhedron:Polyhedron
    radius: fload
    rotation_lon: float
    rotation_lat: fload
    rotation_azimuth: float
    polygon: Polygon
    aperture: int
    projection: string
    transformations: Transformation[]
    global_bounding_polygon: Object
    --
    name: string
    command: string
}

GridSystem ||-- Polyhedron
GridSystem ||-- Polygon

entity Grid {
    COMMENT(concrete tesselation)
    gridSystem: GridSystem
    resolution: int
}

Grid ||- GridSystem


entity DataCube {
    COMMENT(Variables sampled at a specific grid)
    grid: Grid
    metadata: Object[]
    data: n-dimensional array
}

DataCube ||-- Grid

entity Pyramid {
    COMMENT(Same data at different resolution)
    COMMENT(within the same grid system)
    datacubes: DataCube[]
    resolutions: string[spatial, temporal]
}

Pyramid }|--  DataCube

@enduml
```

DGGS data model as an ER diagram.
Attributes above and below the line are required and optional, respectiveley.

## DGGS file format

A DGGS pyramid is stored as one file by mapping the DGGS pyramid class diagram to the [Common Data Model (CDM) V4](https://docs.unidata.ucar.edu/netcdf-java/current/userguide/common_data_model_overview.html#data-access-layer-object-model).
This allows to save the DGGS pyramid in various file formats e.g. NetCDF 4, HDF5 and Zarr.
DGGS data cubes MUST be stored in variables.
DGGS data cubes having the same temporal resolution MUST be stored in the same CDM group.
DGGS data cubes with a single spatiotemporal resolution MUST be stored in the root group.
File names SHOULD contain the phrase `dggs` e.g. `example.dggs.zarr`.
Required attrbutes MUST be stored as meta data in the files.
Cloud optimized file formats allowing HTPP range requests e.g. zarr SHOULD be used.
