# kind of duplicate of Makefile.PL
#	but convenient for Continuous Integration

on 'build' => sub {
    requires 'Text::Glob' => 0;
};

on 'test' => sub {
    requires 'Test::More'      => 0;
    requires 'Test2::Bundle::Extended' => 0;
    requires 'Test2::Tools::Explain'  => 0;
    requires 'Test2::Plugin::NoWarnings'  => 0;
    requires 'File::Slurper'  => 0;
    requires 'Overload::FileCheck' => '0.007';
    requires 'Test::Pod::Coverage' => 0;
    requires 'Test::Pod' => 0;
};
