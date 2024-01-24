function putBall(b,x,y) {
  ball=dd.elements["ball"+b];
  ball.init_x=ball.x;
  ball.init_y=ball.y;
  ball.moveBy((y-0.028575)*500,(x-0.028575)*500);
  ball.setDropFunc(function() {ballMoved(b);});
//  document.getElementById("ball"+b).style.display='inline';
//  document.getElementById("ball"+b).style.left=(y-0.028575)*500 + 'px';
//  document.getElementById("ball"+b).style.top=(x-0.028575)*500 + 'px';
}

function putOOPBall(b) {
  dd.elements["ball"+b].hide();
//  document.getElementById("ball"+b).style.display='none';
}

function ballMoved(b) {
  ball=dd.elements["ball"+b];
  x=(ball.y-ball.init_y)/500+0.028575;
  y=(ball.x-ball.init_x)/500+0.028575;
  update_tablestate(['stateid','args__'+b,'args__'+x,'args__'+y]);
}

function delrow(r) {
  if (r) {
    var row=document.getElementById('row'+r);
    row.parentNode.deleteRow(row.rowIndex);
  }
}
