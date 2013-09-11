requires 'perl', '5.008001';
requires 'B::Generate';
requires 'B::Utils';

on 'test' => sub {
    requires 'Test::More', '0.98';
};

