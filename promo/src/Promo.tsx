import React from "react";
import {
  AbsoluteFill,
  Easing,
  Sequence,
  interpolate,
  spring,
  useCurrentFrame,
  useVideoConfig,
} from "remotion";
import { AVATARS, C, FONT, GRADIENT } from "./theme";

// ---------- shared bits ----------

const Bg: React.FC<{ children: React.ReactNode }> = ({ children }) => (
  <AbsoluteFill
    style={{
      backgroundColor: C.bg,
      fontFamily: FONT,
      backgroundImage:
        "radial-gradient(ellipse 90% 55% at 50% -10%, rgba(255,68,88,0.10), transparent 70%)",
    }}
  >
    {children}
  </AbsoluteFill>
);

const Center: React.FC<{ children: React.ReactNode; gap?: number }> = ({
  children,
  gap = 36,
}) => (
  <AbsoluteFill
    style={{
      justifyContent: "center",
      alignItems: "center",
      flexDirection: "column",
      gap,
      padding: "0 80px",
    }}
  >
    {children}
  </AbsoluteFill>
);

/** Word that punches in with a spring scale. */
const Punch: React.FC<{
  from: number;
  children: React.ReactNode;
  size?: number;
  color?: string;
  gradient?: boolean;
}> = ({ from, children, size = 96, color = C.text, gradient = false }) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const s = spring({ frame: frame - from, fps, config: { damping: 11, mass: 0.6 } });
  const o = interpolate(frame - from, [0, 5], [0, 1], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });
  return (
    <div
      style={{
        fontSize: size,
        fontWeight: 900,
        letterSpacing: -3,
        lineHeight: 1.06,
        textAlign: "center",
        color,
        opacity: o,
        transform: `scale(${0.6 + 0.4 * s})`,
        ...(gradient
          ? {
              backgroundImage: GRADIENT,
              WebkitBackgroundClip: "text",
              WebkitTextFillColor: "transparent",
            }
          : {}),
      }}
    >
      {children}
    </div>
  );
};

const fadeOutLate = (frame: number, sceneLen: number, tail = 10) =>
  interpolate(frame, [sceneLen - tail, sceneLen], [1, 0], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });

// ---------- Scene 1: hook (0–80) ----------

const SceneHook: React.FC<{ len: number }> = ({ len }) => {
  const frame = useCurrentFrame();
  return (
    <Bg>
      <AbsoluteFill style={{ opacity: fadeOutLate(frame, len) }}>
        <Center gap={28}>
          <Punch from={4} size={80} color={C.text2}>
            POV:
          </Punch>
          <Punch from={20} size={104}>
            it&apos;s friday night.
          </Punch>
          <Punch from={44} size={104} gradient>
            nobody wants to go.
          </Punch>
        </Center>
      </AbsoluteFill>
    </Bg>
  );
};

// ---------- Scene 2: the plan card (80–170) ----------

const SceneCard: React.FC<{ len: number }> = ({ len }) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const cardIn = spring({ frame: frame - 12, fps, config: { damping: 13 } });
  return (
    <Bg>
      <AbsoluteFill style={{ opacity: fadeOutLate(frame, len) }}>
        <Center gap={56}>
          <Punch from={0} size={84} color={C.text2}>
            the plan exists…
          </Punch>
          <div
            style={{
              width: 860,
              background: C.surface,
              border: `2px solid ${C.border}`,
              borderRadius: 44,
              padding: 56,
              transform: `translateY(${(1 - cardIn) * 600}px) rotate(${(1 - cardIn) * 4}deg)`,
              boxShadow: "0 40px 90px rgba(0,0,0,0.6)",
            }}
          >
            <div
              style={{
                display: "flex",
                justifyContent: "space-between",
                alignItems: "flex-start",
              }}
            >
              <div>
                <div style={{ fontSize: 58, fontWeight: 800, color: C.text }}>
                  Friday Dinner 🍝
                </div>
                <div style={{ fontSize: 36, color: C.text2, marginTop: 10 }}>
                  Fri 8:00 PM
                </div>
              </div>
              <div
                style={{
                  fontSize: 30,
                  fontWeight: 700,
                  color: C.teal,
                  background: "rgba(78,205,196,0.15)",
                  padding: "12px 26px",
                  borderRadius: 26,
                }}
              >
                All in
              </div>
            </div>
            <div style={{ display: "flex", alignItems: "center", marginTop: 44 }}>
              {AVATARS.map((a, i) => (
                <div
                  key={a.initial}
                  style={{
                    width: 84,
                    height: 84,
                    borderRadius: "50%",
                    background: a.color,
                    border: `5px solid ${C.surface}`,
                    marginLeft: i === 0 ? 0 : -20,
                    display: "flex",
                    alignItems: "center",
                    justifyContent: "center",
                    fontSize: 34,
                    fontWeight: 800,
                    color: "#000",
                  }}
                >
                  {a.initial}
                </div>
              ))}
              <div style={{ fontSize: 32, color: C.text3, marginLeft: 26 }}>
                4 invited
              </div>
            </div>
          </div>
        </Center>
      </AbsoluteFill>
    </Bg>
  );
};

// ---------- Scene 3: secret voting + bail-o-meter (170–310) ----------

const SceneVote: React.FC<{ len: number }> = ({ len }) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();

  const tapAt = 52;
  const tap = spring({ frame: frame - tapAt, fps, config: { damping: 9, mass: 0.5 } });
  const bailPressed = frame >= tapAt;

  // meter fills 0 -> 3 of 3 after the tap
  const fill = interpolate(frame, [tapAt + 14, tapAt + 58], [0, 1], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
    easing: Easing.out(Easing.cubic),
  });
  const count = Math.round(fill * 3);

  const meterIn = spring({ frame: frame - (tapAt + 8), fps, config: { damping: 13 } });

  return (
    <Bg>
      <AbsoluteFill style={{ opacity: fadeOutLate(frame, len) }}>
        <Center gap={48}>
          <Punch from={0} size={88}>
            everyone votes.
          </Punch>
          <Punch from={14} size={88} gradient>
            anonymously.
          </Punch>

          <div style={{ display: "flex", gap: 36, marginTop: 30 }}>
            <div
              style={{
                width: 380,
                padding: "52px 0",
                textAlign: "center",
                fontSize: 46,
                fontWeight: 800,
                color: C.text,
                background: C.surface,
                border: `2px solid ${C.border}`,
                borderRadius: 38,
              }}
            >
              🙌 I&apos;m In
            </div>
            <div
              style={{
                width: 380,
                padding: "52px 0",
                textAlign: "center",
                fontSize: 46,
                fontWeight: 800,
                color: "#fff",
                background: bailPressed ? GRADIENT : C.surface,
                border: `2px solid ${bailPressed ? "transparent" : C.border}`,
                borderRadius: 38,
                transform: `scale(${bailPressed ? 0.92 + 0.08 * tap : 1})`,
                boxShadow: bailPressed
                  ? "0 24px 70px rgba(255,68,88,0.45)"
                  : "none",
              }}
            >
              🚪 Bail
            </div>
          </div>

          <div
            style={{
              width: 800,
              marginTop: 40,
              opacity: meterIn,
              transform: `translateY(${(1 - meterIn) * 80}px)`,
            }}
          >
            <div
              style={{
                display: "flex",
                justifyContent: "space-between",
                fontSize: 30,
                fontWeight: 700,
                color: C.text3,
                letterSpacing: 3,
                marginBottom: 18,
              }}
            >
              <span>BAIL-O-METER</span>
              <span style={{ color: count >= 3 ? C.accentStart : C.text3 }}>
                {count}/3 to cancel
              </span>
            </div>
            <div
              style={{
                height: 26,
                borderRadius: 14,
                background: C.border,
                overflow: "hidden",
              }}
            >
              <div
                style={{
                  height: "100%",
                  width: `${fill * 100}%`,
                  background: GRADIENT,
                  borderRadius: 14,
                }}
              />
            </div>
          </div>
        </Center>
      </AbsoluteFill>
    </Bg>
  );
};

// ---------- Scene 4: it's dead (310–430) ----------

const SceneDead: React.FC<{ len: number }> = ({ len }) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const drop = spring({ frame: frame - 4, fps, config: { damping: 10, mass: 0.9 } });
  const flash = interpolate(frame, [0, 3, 12], [0, 0.55, 0], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });
  const bubbleIn = spring({ frame: frame - 40, fps, config: { damping: 13 } });
  return (
    <Bg>
      <AbsoluteFill style={{ opacity: fadeOutLate(frame, len) }}>
        <Center gap={44}>
          <div
            style={{
              fontSize: 220,
              transform: `translateY(${(1 - drop) * -700}px) scale(${0.7 + 0.3 * drop})`,
            }}
          >
            💀
          </div>
          <Punch from={10} size={130} gradient>
            It&apos;s dead.
          </Punch>
          <div
            style={{
              maxWidth: 820,
              background: "#1f8a3b",
              borderRadius: 44,
              borderBottomLeftRadius: 12,
              padding: "40px 48px",
              fontSize: 42,
              lineHeight: 1.35,
              color: "#fff",
              opacity: bubbleIn,
              transform: `translateY(${(1 - bubbleIn) * 120}px)`,
              marginTop: 20,
            }}
          >
            &ldquo;Hey, plans fell through for Friday. Maybe next time! 🤷&rdquo;
          </div>
        </Center>
        <AbsoluteFill
          style={{ background: C.accentStart, opacity: flash, pointerEvents: "none" }}
        />
      </AbsoluteFill>
    </Bg>
  );
};

// ---------- Scene 5: anonymity (430–515) ----------

const SceneAnon: React.FC<{ len: number }> = ({ len }) => {
  const frame = useCurrentFrame();
  return (
    <Bg>
      <AbsoluteFill style={{ opacity: fadeOutLate(frame, len) }}>
        <Center gap={40}>
          <Punch from={2} size={96}>
            nobody knows
          </Punch>
          <Punch from={14} size={96}>
            who bailed.
          </Punch>
          <Punch from={36} size={56} color={C.text2}>
            no names. no blame. no drama.
          </Punch>
        </Center>
      </AbsoluteFill>
    </Bg>
  );
};

// ---------- Scene 6: CTA (515–600) ----------

const SceneCTA: React.FC<{ len: number }> = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const logoIn = spring({ frame: frame - 4, fps, config: { damping: 11 } });
  const pulse = 1 + 0.025 * Math.sin((frame / fps) * Math.PI * 2.4);
  const line = (from: number) =>
    interpolate(frame - from, [0, 10], [0, 1], {
      extrapolateLeft: "clamp",
      extrapolateRight: "clamp",
    });
  return (
    <Bg>
      <Center gap={36}>
        <div
          style={{
            width: 300,
            height: 300,
            borderRadius: 72,
            background: GRADIENT,
            display: "flex",
            alignItems: "center",
            justifyContent: "center",
            fontSize: 150,
            fontWeight: 900,
            color: "#fff",
            transform: `scale(${logoIn * pulse})`,
            boxShadow: "0 50px 130px rgba(255,68,88,0.45)",
          }}
        >
          b.
        </div>
        <div
          style={{
            fontSize: 120,
            fontWeight: 900,
            letterSpacing: -5,
            color: C.text,
            opacity: line(14),
          }}
        >
          bail.out
        </div>
        <div style={{ fontSize: 46, color: C.text2, opacity: line(22) }}>
          free on the App Store
        </div>
        <div
          style={{
            fontSize: 38,
            fontWeight: 700,
            color: C.text3,
            opacity: line(30),
          }}
        >
          @BailOutAppHQ
        </div>
      </Center>
    </Bg>
  );
};

// ---------- timeline ----------

const SCENES: { len: number; comp: React.FC<{ len: number }> }[] = [
  { len: 80, comp: SceneHook },
  { len: 90, comp: SceneCard },
  { len: 140, comp: SceneVote },
  { len: 120, comp: SceneDead },
  { len: 85, comp: SceneAnon },
  { len: 85, comp: SceneCTA },
];

export const TOTAL_FRAMES = SCENES.reduce((a, s) => a + s.len, 0);

export const Promo: React.FC = () => {
  let at = 0;
  return (
    <AbsoluteFill style={{ backgroundColor: C.bg }}>
      {SCENES.map(({ len, comp: Scene }, i) => {
        const from = at;
        at += len;
        return (
          <Sequence key={i} from={from} durationInFrames={len}>
            <Scene len={len} />
          </Sequence>
        );
      })}
    </AbsoluteFill>
  );
};
