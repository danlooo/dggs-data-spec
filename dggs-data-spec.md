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

However, no file format exist so far to store DGGS data natively.
This document aims to specify a suitable file format to suggest using it in further parts of [ISO 19170-1:2020](https://www.iso.org/standard/32588.html).

## DGGS

A DGGS is defined in [ISO 19170-1:2020](https://www.iso.org/standard/32588.html).

Briefly, a discrete global grid can be created using:

1. Take a platonic solid
1. Set the radius of it to those of the sphere
1. Set the rotational orientation of the solid relative to the sphere
1. Tesselate the surface of the solid using regular polygons defining the zones
1. Re-project the cell boundaries to the surface of the sphere

A DGGS is created by iteratively creating grids at decreasing spatial resolutions.
Hereby, a parent-child relationship is defined between zones of successive resolutions.

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

Cells MUST be the same polygons whenever possible. For example, tessellations of the surface of a icosahedron with hexagons requires to add 12 pentagons.

## Zone identifier

A Zone identifier is defined in [ISO 19170-1:2020](https://www.iso.org/standard/32588.html).
Briefly, Zone identifiers are unique labels of zones.

There MAY be multiple systems of zone identifiers describing zones of the same grid, e.g., SEQNUM, PROJTRI and Q2DI for DGGRID grids, among others.

Zones with similar zone identifiers MUST be nearby in geographical space.

Zone identifiers:

- MAY be tuples having multiple dimensions, e.g., DGGRID PROJTRI
- MAY encode a hierarchical relationship between zones at different spatial resolutions, e.g. using prefix codes in Uber H3
- MAY encode information about the angular direction to child zones (e.g. using Generalized balanced ternaries or Central Place Indexing [(Sahr 2013)](http://dx.doi.org/10.3138/cart.54.1.2018-0022)

## DGGS Array Coordinates

DGGS array coordinate is the position of a particular zone in a array of the DGGS data cube.
It defines how the zones are stored in memory.
This affects the chunking and loading time of the data.

DGGS array coordinates MUST be cartesian non-negative integers.
DGGS array coordinates MAY have one or many dimensions.
Points nearby in geographical space SHOULD also be nearby using DGGS array coordinates.

![Net of an icosahedron](assets/icosahedron-net.png)

**Figure 1**: Merging 2 faces of a polyhedron to one rectangular chart [(Mahdavi-Amiri et al. 2014)](http://dx.doi.org/10.1080/17538947.2014.927597).

# Coordinate conversion

Coordinate conversions are a sequence of bijective functions describing how to convert WGS84 geographical coordinates to DGGS array coordinates (positions) and vice versa.
Forward and backward coordinate conversion result in DGGS array coordinates and geographical coordinates, respectively.

```mermaid
flowchart LR
    geo["
        Geographical coordinates

        (lon, lat)
    "]
    dggs["
        DGGS coordinates

        e.g. PROTRI (face, x, y)
    "]
    array["
        DGGS Array coordinates

        non-negative integers
        e.g. (i, j)
    "]

    geo -->|forward| dggs -->|forward| array
    array -->|backward| dggs -->|backward| geo
```

Coordinate conversion MAY be composed of multiple steps.
The coordinate conversion SHOULD be compact in the positional array space, i.e. there SHOULD be (almost) no skipped array position.
Coordinate conversion function MUST be compatible with the selected GridSystem.

Example with one step of grids produced by DGGRID:

```json
[
  {
    "type": "dggrid",
    "version": "7.8",
    "address_type": "Q2DI"
  }
]
```

The parameter `type` MUST be provided in every coordinate conversion call.

Notes:

1.  The sequence is implemented as a JSON list, because JSON dictionaries are unordered.

## DGGRID coordinate conversion

This will call DGGRID.
Other required parameters will be inferred from the Grid object.
A error message MUST be raised if this was unsuccessful (DGGRID not installed, ambiguous parameters, missing parameters, etc.)

| name         | type   | description                                                                                                                                          |
| ------------ | ------ | ---------------------------------------------------------------------------------------------------------------------------------------------------- |
| version      | string | Version of DGGRID to be used                                                                                                                         |
| address_type | string | address type as used by DGGRID parameter as defined by `output_address_type` for forward and `input_address_type` for backward coordinate conversion |

## Linear coordinate conversion

This is an implementation of [GDAL Geotransform](https://gdal.org/tutorials/geotransforms_tut.html).

| name | type   | description                                                                |
| ---- | ------ | -------------------------------------------------------------------------- |
| gt0  | number | x-coordinate of the upper-left corner of the upper-left pixel.             |
| gt1  | number | w-e pixel resolution / pixel width.                                        |
| gt2  | number | row rotation (typically zero).                                             |
| gt3  | number | y-coordinate of the upper-left corner of the upper-left pixel.             |
| gt4  | number | column rotation (typically zero).                                          |
| gt5  | number | n-s pixel resolution / pixel height (negative value for a north-up image). |

## DGGS Data Cube

A (regular) DGGS data cube is an n-dimensional array to store values of variables across the globe.
The values are arranged on a selected grid and zone index.
A user focused definition describes (geo) data cubes as a "discretized model of the earth that offers estimated values of certain variables for each partition of the Earth’s surface called a cell" [(OGC 2021)](https://www.ogc.org/initiatives/gdc).

There MUST be at least all spatial dimensions present needed for the selected zone identifier.
Values MUST be sampled in accordance to the selected grid.
DGGS data cubes are regular, i.e. there MUST NOT be missing values within the global bounding box.
Values MAY be interpolated.

## DGGS resolution

A DGGS resolution is collection of dimensions and a corresponding number representing the resolution level.
More detailed data cubes with a higher resolution have higher numbers.
A DGGS grid MUST have one resolution on spatial dimensions defined.
In addition, spatiotemporal DGGS grid MUST have one resolution on a temporal dimension defined.
Each dimension MUST NOT be used multiple times in all resolution definitions.
Only spatial or temporal dimensions SHOULD be used.

Example for a DGGRID grid with `dggs_res_spec` of 8 and PROJTRI zone identifiers:

```json
{
  "name": "spatial",
  "dimensions": ["triangle", "x", "y"],
  "resolution": 8
}
```

## DGGS Pyramid

A DGGS data cube pyramid is a collection of DGGS data cubes.
The only difference of those DGGS data cubes is that they have at least different spatial resolutions.
Different temporal resolutions MAY be created as well yielding spatiotemporal DGGS.
Is so, all temporal resolutions MUST be created for all spatial resolutions (cross product).

Resolution is a property of a collection of axes

## DGGS Data Model

```mermaid
classDiagram
    class Polyhedron {
        <<enumeration>>
        tetrahedron
        cube
        octahedron
        dodecahedron
        icosahedron
    }

    class Polygon {
        <<enumeration>>
        triangle
        quadliteral
        pentagon
        hexagon
    }

    class DGGRIDAddressType {
        <<enumeration>>
        GEO
        SEQNUM
        PROJTRI
        Q2DD
        Q2DI
    }

    class Resolution {
        name: string
        dimensions: string[]
        resolution: number
    }

    class CoordinateConversion {
        <<Abstract>>
        type: string
    }

    class DGGRIDCoordinateConversion {
        version:string
        address_type: DGGRIDAddressType
    }
    DGGRIDCoordinateConversion <|-- CoordinateConversion
    DGGRIDCoordinateConversion "1" --> "1" DGGRIDAddressType

    class LinearCoordinateConversion {
        gt0: number
        gt1: number
        gt2: number
        gt3: number
        gt4: number
        gt5: number
    }
    LinearCoordinateConversion <|-- CoordinateConversion

    class GridSystem {
        name: string
        polyhedron: Polyhedron
        polygon: Polygon
        radius: float
        rotation_lon: float
        rotation_lat: float
        rotation_azimuth: float
        projection: string
        global_bounding_polygon: string (WKT POLYGON)
    }
    GridSystem "1" --> "1" Polyhedron
    GridSystem "1" --> "1" Polygon

    class Grid {
        grid_system: GridSystem
        transformations: CoordinateConversion[] [1]
        resolutions: Resolution[]
        aperture: number

        zone_id(lat, lon): number[]
        geo(zone_id): (lon:number, lat:number)
    }
    Grid "1" --> "*" CoordinateConversion
    Grid "1" --> "1" GridSystem
    Grid "1" --> "1..*" Resolution

    class DataCube {
        grid: Grid
        metadata: dict
        data: n-dimensional array
    }
    DataCube "1" --> "1" Grid

    class DataCubePyramid {
        datacubes: DataCube[]
    }
   DataCubePyramid "1" --> "1..*" DataCube
```

DGGS data model as an ER diagram.
Attributes above and below the line are required and optional, respectively.

Notes:

1. Some grids (e.g. ISEA7H) requires different coordinate conversions at successive resolutions (pointy top vs flat top, Class I vs Class II)

Everything but the n-dimensional array itself of the DGGS data model will be stored as attributes of that array.
Example attributes of a DGGS data cube at a given resolution:

```json
{
  "metadata": {
    "is_exaple": true,
    "description": "Example data was generated from a function."
  },
  "grid": {
    "coordinate_conversions": [
      {
        "version": "7.8",
        "address_type": "Q2DI",
        "type": "dggrid"
      }
    ],
    "aperture": 4,
    "grid_system": {
      "rotation_lon": 11.25,
      "polyhedron": "icosahedron",
      "name": "ISEA4H",
      "radius": 6371007.180918475,
      "polygon": "hexagon",
      "rotation_lat": 58.2825,
      "projection": "Snyder Equal Area",
      "rotation_azimuth": 0
    },
    "resolutions": [
      {
        "name": "spatial",
        "resolution": 4,
        "dimensions": [
          "n",
          "i",
          "j"
        ]
      },
      {
        "name": "temporal",
        "resolution": 1,
        "dimensions": [
          "time"
        ]
      }
    ]
  }
}
```

## DGGS file format

A DGGS pyramid is stored as one file by mapping the DGGS pyramid class diagram to the [Common Data Model (CDM) V4](https://docs.unidata.ucar.edu/netcdf-java/current/userguide/common_data_model_overview.html#data-access-layer-object-model).
This allows to save the DGGS pyramid in various file formats e.g. NetCDF 4, HDF5 and Zarr.
DGGS data cubes MUST be stored in variables.
DGGS data cubes having the same temporal resolution MUST be stored in the same CDM group.
DGGS data cubes with a single spatiotemporal resolution MUST be stored in the root group.
File names SHOULD contain the phrase `dggs` e.g. `example.dggs.zarr`.
Required attrbutes MUST be stored as meta data in the files.
Cloud optimized file formats allowing HTPP range requests e.g. zarr SHOULD be used.
