requires 'perl', '5.008001';
requires 'B::Generate';
requires 'B::Utils';
requires 'Text::Truncate';
requires 'Scope::Guard';
requires 'Module::Load';

on 'test' => sub {
    requires 'Test::More', '0.98';
};

