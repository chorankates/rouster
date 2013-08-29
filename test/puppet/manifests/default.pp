## common entry-point into Puppet config.

if ($::virtual == 'virtualbox') {
    $data_center = 'vagrant'
} else {
    $data_center = 'amazon'
}

include role::ui
