String numberToWords(int number) {
  if (number == 0) return 'Zero';
  if (number < 0) return 'Minus ${numberToWords(number.abs())}';

  const ones = [
    '',
    'One',
    'Two',
    'Three',
    'Four',
    'Five',
    'Six',
    'Seven',
    'Eight',
    'Nine',
  ];
  const teens = [
    'Ten',
    'Eleven',
    'Twelve',
    'Thirteen',
    'Fourteen',
    'Fifteen',
    'Sixteen',
    'Seventeen',
    'Eighteen',
    'Nineteen',
  ];
  const tens = [
    '',
    '',
    'Twenty',
    'Thirty',
    'Forty',
    'Fifty',
    'Sixty',
    'Seventy',
    'Eighty',
    'Ninety',
  ];

  String helper(int n) {
    if (n == 0) return '';
    if (n < 10) return ones[n];
    if (n < 20) return teens[n - 10];
    if (n < 100) return '${tens[n ~/ 10]} ${ones[n % 10]}'.trim();
    if (n < 1000) return '${ones[n ~/ 100]} Hundred ${helper(n % 100)}'.trim();
    if (n < 100000) return '${helper(n ~/ 1000)} Thousand ${helper(n % 1000)}'.trim();
    if (n < 10000000) return '${helper(n ~/ 100000)} Lakh ${helper(n % 100000)}'.trim();
    return '${helper(n ~/ 10000000)} Crore ${helper(n % 10000000)}'.trim();
  }

  return helper(number);
}
