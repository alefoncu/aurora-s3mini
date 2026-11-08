D=/dev/input/event2
s() { sendevent $D $1 $2 $3; }
s 3 47 0; s 3 57 100; s 3 53 215; s 3 54 400; s 3 58 80; s 0 0 0
s 3 47 1; s 3 57 101; s 3 53 265; s 3 54 400; s 3 58 80; s 0 0 0
for i in 1 2 3 4 5 6 7 8; do
  x0=$((215 - i*15)); x1=$((265 + i*15))
  s 3 47 0; s 3 53 $x0; s 3 54 400; s 0 0 0
  s 3 47 1; s 3 53 $x1; s 3 54 400; s 0 0 0
done
sleep 0.3
echo SHOT
