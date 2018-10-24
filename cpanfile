requires 'Test2::Bundle::Extended';
requires 'Test2::Tools::Explain';
requires 'Test2::Plugin::NoWarnings';
on 'develop' => sub {
    requires 'Test::CheckManifest';
};
