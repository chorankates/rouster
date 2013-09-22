class role::ui {
    notify {'role::ui::notify':
        message => "role::ui configured for ${::data_center}",
    }
}
