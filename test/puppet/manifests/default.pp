## common entry-point into Puppet config.

## if is_vagrant is defined, then we're running under Vagrant.  Use other
## logic/facts to detect environmental stuff.
if $::is_vagrant {
    $data_center = 'vagrant'
} else {
    $data_center = 'amazon'
}

include role::ui
