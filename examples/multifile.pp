


kdbmount { 'user/test/mm':
  file    => 'mmtest.json',
  #file    => 'mmtest.ini',
  plugins => ['json', 'type', 'enum']
  #plugins => ['ini', 'type', 'enum']
}


kdbkey {
  'user/test/mm/s1':             value => "ss1";
  'user/test/mm/s2':             value => 'ss2';
  'user/test/mm/section abc/x1': value => 'sec_x1';
  'user/test/mm/section abc/x2': value => 'sec_x2';
  'user/test/mm/section xyz/y1': value => 'sec_y1';
  'user/test/mm/section xyz/y2': value => 'sec_y2';
}
