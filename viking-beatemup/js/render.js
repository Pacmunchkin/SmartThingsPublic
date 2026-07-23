/*
 * Canvas renderer: a moody Northumbrian field at dusk, two fighters,
 * and their health/stamina bars. Placeholder vector art for now —
 * sprite sheets can replace drawFighter() later without touching the engine.
 */

const GROUND_Y = 400;

function drawScene(ctx, player, enemy) {
  const w = ctx.canvas.width;
  const h = ctx.canvas.height;

  // Dusk sky
  const sky = ctx.createLinearGradient(0, 0, 0, GROUND_Y);
  sky.addColorStop(0, '#2b2f3a');
  sky.addColorStop(0.7, '#5a4a4a');
  sky.addColorStop(1, '#7a5a45');
  ctx.fillStyle = sky;
  ctx.fillRect(0, 0, w, GROUND_Y);

  // Distant hills
  ctx.fillStyle = '#252a26';
  ctx.beginPath();
  ctx.moveTo(0, GROUND_Y);
  ctx.quadraticCurveTo(w * 0.25, GROUND_Y - 90, w * 0.5, GROUND_Y - 30);
  ctx.quadraticCurveTo(w * 0.75, GROUND_Y - 100, w, GROUND_Y - 40);
  ctx.lineTo(w, GROUND_Y);
  ctx.closePath();
  ctx.fill();

  // Ground
  ctx.fillStyle = '#3a3d2e';
  ctx.fillRect(0, GROUND_Y, w, h - GROUND_Y);

  drawFighter(ctx, player);
  drawFighter(ctx, enemy);

  drawStatus(ctx, player, 20, 20);
  drawStatus(ctx, enemy, w - 260, 20, true);
}

function drawFighter(ctx, f) {
  const x = f.x;
  const y = GROUND_Y;
  const dir = f.facing;
  const p = f.palette;
  const dead = f.hp <= 0;

  ctx.save();
  ctx.translate(x, y);
  if (dead) {
    // Fallen: lay the figure down
    ctx.rotate(dir * Math.PI / 2);
    ctx.translate(0, -14);
  }

  // Legs
  ctx.strokeStyle = '#2a2622';
  ctx.lineWidth = 10;
  ctx.beginPath();
  ctx.moveTo(-10, 0); ctx.lineTo(-6, -45);
  ctx.moveTo(10, 0); ctx.lineTo(6, -45);
  ctx.stroke();

  // Tunic
  ctx.fillStyle = p.tunic;
  ctx.fillRect(-18, -105, 36, 62);
  ctx.fillStyle = p.trim;
  ctx.fillRect(-18, -105, 36, 6);

  // Head
  ctx.fillStyle = '#d9b38c';
  ctx.beginPath();
  ctx.arc(0, -122, 15, 0, Math.PI * 2);
  ctx.fill();

  // Hair / beard
  ctx.fillStyle = p.hair;
  ctx.fillRect(-15, -132, 30, 8);
  ctx.fillRect(-10, -115, 20, 10);

  // Shield arm (back side)
  ctx.fillStyle = p.shield;
  ctx.beginPath();
  ctx.arc(-dir * 24, -85, f.guarding ? 26 : 18, 0, Math.PI * 2);
  ctx.fill();
  ctx.strokeStyle = '#1d1d1d';
  ctx.lineWidth = 3;
  ctx.stroke();

  // Weapon arm: an axe held forward
  ctx.strokeStyle = '#d9b38c';
  ctx.lineWidth = 8;
  ctx.beginPath();
  ctx.moveTo(dir * 12, -95);
  ctx.lineTo(dir * 34, -110);
  ctx.stroke();
  ctx.strokeStyle = '#6b4f2a';
  ctx.lineWidth = 5;
  ctx.beginPath();
  ctx.moveTo(dir * 34, -110);
  ctx.lineTo(dir * 44, -140);
  ctx.stroke();
  ctx.fillStyle = '#9aa0a8';
  ctx.beginPath();
  ctx.moveTo(dir * 44, -140);
  ctx.lineTo(dir * 60, -132);
  ctx.lineTo(dir * 44, -124);
  ctx.closePath();
  ctx.fill();

  ctx.restore();

  // Stun stars
  if (f.stunned && !dead) {
    ctx.fillStyle = '#c9a227';
    ctx.font = '20px Georgia';
    ctx.fillText('✶ ✶', x - 18, y - 150);
  }
}

function drawStatus(ctx, f, x, y, rightAlign = false) {
  const BAR_W = 240;

  ctx.fillStyle = '#d8c9a3';
  ctx.font = 'bold 16px Georgia';
  ctx.textAlign = rightAlign ? 'right' : 'left';
  ctx.fillText(`${f.name} ${f.epithet}`, rightAlign ? x + BAR_W : x, y + 14);
  ctx.textAlign = 'left';

  drawBar(ctx, x, y + 22, BAR_W, 14, f.hp / f.maxHp, '#8a1f1f', `${f.hp}/${f.maxHp}`);
  drawBar(ctx, x, y + 40, BAR_W, 10, f.stamina / f.maxStamina, '#c9a227',
          `${f.stamina}/${f.maxStamina}`);
}

function drawBar(ctx, x, y, w, h, ratio, color, label) {
  ctx.fillStyle = '#101317';
  ctx.fillRect(x, y, w, h);
  ctx.fillStyle = color;
  ctx.fillRect(x, y, w * Math.max(0, ratio), h);
  ctx.strokeStyle = '#3b3f45';
  ctx.lineWidth = 2;
  ctx.strokeRect(x, y, w, h);
  ctx.fillStyle = '#d8c9a3';
  ctx.font = '10px Georgia';
  ctx.fillText(label, x + w + 6, y + h - 1);
}
