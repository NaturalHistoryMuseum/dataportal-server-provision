var config = {
    port: 4000, /* Port to the application. This is not directly Windshaft, but a proxy to queue and prioritize requests */
    postgres_host: '%DB_HOST%',
    postgres_port: 5432,
    postgres_user: '%DB_USER%',
    postgres_pass: '%DB_PASS%',
    geometry_field: '_the_geom_webmercator',
    geometry_4326_field: '_geom',
    id_field: '_id',
    resources_path: __dirname + '/resources',
    num_workers: 1, /* If CPU bound, then set this to the number of CPUs and no more */
    worker_max_requests: 1000, /* 0 to disable this feature */
    requests_per_client: 4, /* Internally, number of requests for the proxy to send to windshaft per client at once */
    windshaft_port: 4001, /* Internally, Windshaft runs on this port */
    /* Specific filter handlers. Note that the default _tmgeom handler is expected by the
       map component for geometric searches. See README.md for format/options. */
    query_options : {
        '_tmgeom': 'ST_Intersects({geom_field}, ST_Transform(ST_GeomFromText({option_value}, 4326), 3857))',
        '_has_type': '{resource}."typeStatus" IS NOT NULL',
        '_has_image': '{resource}."associatedMedia" IS NOT NULL',
        '_has_lat_long': '{resource}."_geom" IS NOT NULL',
        '_exclude_centroid': 'NOT (LOWER({resource}."centroid"::text) = ANY(\'{{true,yes,1}}\'))'
    }
};
/* Don't remove this */
module.exports = config;