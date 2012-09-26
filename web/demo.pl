use strict;

Doc->template('base')->{document_ready} .= 
        "\n nody.ajax({ a:'ajGraph', domid:'main_block', graph_id:'traf_xxx', y_title:'МБайт' });";