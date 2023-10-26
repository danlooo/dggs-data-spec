#
# This is an pilot of the ISEA4H DGGS with axial Q2DI coordinates.
#
# DGGRID
#   - ISEA is more equal area than H3 or S2
#   - more shape options to test (hexagons, diamonds and triangles)
# Aperture 4
#   - No alternating hexagon class (corner or side at top)
#   - smoother pyramid zooming, finer control of grid sizes
#   - easier to store it in tensors
# Hexagons
#   - More accurate CNN: Less angular distortions, rotational equivariance
# Axial coordinates
#   - Fast bounding box queries (viewing and convolutions), easy tiling for chunks having nearby cells
#

using YAXArrays
using DimensionalData
using Plots
using DGGRID7_jll
using CSV
using DataFrames
using Rasters
using Infiltrator
using Statistics
using Zarr
using NetCDF
using OrderedCollections
using Dates

"""
Execute sytem call of DGGRID binary
"""
function call_dggrid(meta::Dict; verbose=false)
    meta_string = ""
    for (key, val) in meta
        meta_string *= "$(key) $(val)\n"
    end

    tmp_dir = tempname()
    mkdir(tmp_dir)
    meta_path = tempname() # not inside tmp_dir to avoid name collision
    write(meta_path, meta_string)

    DGGRID7_jll.dggrid() do dggrid_path
        old_pwd = pwd()
        cd(tmp_dir)
        oldstd = stdout
        if !verbose
            redirect_stdout(devnull)
        end
        run(`$dggrid_path $(meta_path)`)
        cd(old_pwd)
        redirect_stdout(oldstd)
    end

    rm(meta_path)
    return (tmp_dir)
end

function geo_grid_to_cell_matrix(lons::AbstractVector, lats::AbstractVector, level::Int=10, dggs_type::String="")
    input_coords = ""
    for (lon, lat) in Iterators.product(lons, lats)
        # remove sign of zero
        input_coords *= "$(lon+0) $(lat+0)\n"
    end
    input_coords_path = tempname()
    write(input_coords_path, input_coords)

    meta = Dict(
        "dggrid_operation" => "TRANSFORM_POINTS",
        "dggs_type" => uppercase(string(dggs_type)),
        "dggs_res_spec" => string(level - 1),
        "input_file_name" => input_coords_path,
        "input_address_type" => "GEO",
        "input_delimiter" => "\" \"",
        "output_file_name" => "out.txt",
        "output_address_type" => "Q2DI",
        "output_delimiter" => "\" \""
    )


    out_dir = call_dggrid(meta)
    rm(input_coords_path)

    res = CSV.read("$out_dir/out.txt", DataFrame; header=[:quad_n, :quad_i, :quad_j])

    rm(out_dir, recursive=true)
    res = res |> eachrow .|> Tuple |> x -> reshape(x, length(lons), length(lats))
    return res
end

# create raster data
lon_range = -180:0.8:180
lat_range = -90:0.8:90
axlist = (
    Dim{:lon}(lon_range),
    Dim{:lat}(lat_range),
    Dim{:time}(Date("2022-01-01"):Day(1):Date("2022-01-10"))
)
data = [exp(cosd(lon)) + t * (lat / 90) for lon in lon_range, lat in lat_range, t in 1:10]
geo_cube = YAXArray(axlist, data)

# create dggs cell mapping matrix by transforming all points of the raster grid to axial DGGS coords using DGGRID.
# Intended to be the first step of conversion from raster data to DGGS data cube, i.e. DGGS level at highest resolution.
# We don't want to loose information, so the number of DGGS cells should be similar to the number of raster pixels.
# Thus, this is more pixel re-arragement and less aggregation.
# We don't want to mask the raster with DGGS cell bounding boxes, because this will produce much more data. Thus transform grid points instead.

function get_cell_cube(geo_cube, resolution)
    raster_cell_mapping = geo_grid_to_cell_matrix(geo_cube.lon.val, geo_cube.lat.val, resolution, "ISEA4H")
    cells = raster_cell_mapping |> unique

    cell_indices = map(cells) do cell
        findall(isequal(cell), raster_cell_mapping)
    end

    function transform_cube(xout, xin, cells, cell_indices, agg_func::Function)
        cell_values = map(x -> agg_func(view(xin, x)), cell_indices)

        for (cell_val, cell_id) in zip(cell_values, cells)
            xout[cell_id[1]+1, cell_id[2]+1, cell_id[3]+1] = cell_val
        end
    end

    # Spatial axes are unique to each resolution and thus have a differnt name to prevent shared axes
    # Sharing a time axis, howeverm is fine
    outdims = [
        Dim{:n}(minimum(cells .|> x -> x[1] + 1):maximum(cells .|> x -> x[1])+2), #quad 0 and 11 hold just one vertex
        Dim{:i}(minimum(cells .|> x -> x[2])+1:maximum(cells .|> x -> x[2])+1),
        Dim{:j}(minimum(cells .|> x -> x[3])+1:maximum(cells .|> x -> x[3])+1)
    ]

    cell_cube = mapCube(
        transform_cube,
        geo_cube,
        cells,
        cell_indices,
        mean,
        indims=InDims(:lon, :lat),
        outdims=OutDims(outdims...)
    )
    return (cell_cube)
end

resolution = 4
cell_cube = get_cell_cube(geo_cube, resolution)

WGS84_AUTHALIC_EARTH_RADIUS = 6371007.180918475
cell_cube_props = Dict(
    :grid => Dict(
        :grid_system => Dict(
            :name => "ISEA4H",
            :polyhedron => :icosahedron,
            :polygon => :hexagon,
            :radius => WGS84_AUTHALIC_EARTH_RADIUS,
            :rotation_lon => 11.25,
            :rotation_lat => 58.2825,
            :rotation_azimuth => 0,
            :zone_identifier => "DGGRID-7.8-Q2DI",
            :projection => "Snyder Equal Area"
        ),
        :transformations => [
            Dict(
                :type => "dggrid",
                :version => "7.8"
            )
        ],
        :resolutions => [
            Dict(
                :name => "spatial",
                :dimensions => [:n, :i, :j],
                :resolution => resolution
            ),
            Dict(
                :name => "temporal",
                :dimensions => [:time],
                :resolution => 1
            )
        ],
        :aperture => 4
    ),
    :metadata => Dict(
        :is_exaple => true,
        :description => "Example data was generated from a function."
    )
)
ds = Dataset(; properties=cell_cube_props, cell_cube)
savedataset(ds; path="example.dggs.zarr", driver=:zarr, overwrite=true)