#{{resource_id}} {
    marker-fill: {{fill_color}};
    [Centroid = 'true'] {marker-fill: #0000FF;}
    [Centroid = 'True'] {marker-fill: #0000FF;}
    [Centroid = 'TRUE'] {marker-fill: #0000FF;}
    [Centroid = 'yes'] {marker-fill: #0000FF;}
    [Centroid = 'Yes'] {marker-fill: #0000FF;}
    [Centroid = 'YES'] {marker-fill: #0000FF;}
    [Centroid = '1'] {marker-fill: #0000FF;}
    marker-opacity: 1;
    marker-width: {{marker_size}} - 1;
    marker-line-color: {{line_color}};
    marker-line-width: 1;
    marker-line-opacity: 0.9;
    marker-placement: point;
    marker-type: ellipse;
    marker-allow-overlap: true;
}