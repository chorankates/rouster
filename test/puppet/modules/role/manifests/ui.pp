# public_hostname will be looked up in hiera as role::ui::public_hostname
class role::ui (
    $public_hostname
) {
    notify {'role::ui::notify':
        message => "role::ui configured for ${::data_center}; hostname: $public_hostname",
    }
}
