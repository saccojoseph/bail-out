import { useState } from "react";

const screens = ["splash", "home", "create", "event", "vote", "cancelled", "confirmed"];

const friends = [
  { id: 1, name: "Sarah", avatar: "S", color: "#FF6B6B" },
  { id: 2, name: "Mike", avatar: "M", color: "#4ECDC4" },
  { id: 3, name: "Jess", avatar: "J", color: "#FFE66D" },
  { id: 4, name: "Dan", avatar: "D", color: "#A8E6CF" },
  { id: 5, name: "Kat", avatar: "K", color: "#FF8B94" },
];

const sampleEvents = [
  { id: 1, title: "Dinner at Zinc", time: "Sat 7:00 PM", guests: [1,2,3,4], bails: 2, threshold: 3, status: "pending" },
  { id: 2, title: "Bowling Night", time: "Fri 8:00 PM", guests: [1,3,5], bails: 0, threshold: 2, status: "pending" },
];

export default function BailApp() {
  const [screen, setScreen] = useState("splash");
  const [voted, setVoted] = useState(null);
  const [showResult, setShowResult] = useState(false);
  const [selectedGuests, setSelectedGuests] = useState([1, 2, 3]);
  const [threshold, setThreshold] = useState("majority");
  const [eventTitle, setEventTitle] = useState("Dinner at Zinc");
  const [eventTime, setEventTime] = useState("Sat 7:00 PM");
  const [createStep, setCreateStep] = useState(1);

  const handleVote = (choice) => {
    setVoted(choice);
    setTimeout(() => setShowResult(true), 800);
  };

  const toggleGuest = (id) => {
    setSelectedGuests(prev =>
      prev.includes(id) ? prev.filter(g => g !== id) : [...prev, id]
    );
  };

  const Phone = ({ children, bg = "#0a0a0a" }) => (
    <div style={{
      width: 375,
      minHeight: 812,
      background: bg,
      borderRadius: 50,
      border: "10px solid #1a1a1a",
      boxShadow: "0 40px 100px rgba(0,0,0,0.6), inset 0 0 0 2px #333",
      position: "relative",
      overflow: "hidden",
      display: "flex",
      flexDirection: "column",
      fontFamily: "'SF Pro Display', -apple-system, sans-serif",
    }}>
      {/* Notch */}
      <div style={{
        position: "absolute", top: 0, left: "50%", transform: "translateX(-50%)",
        width: 120, height: 34, background: "#1a1a1a",
        borderRadius: "0 0 20px 20px", zIndex: 100,
      }} />
      <div style={{ paddingTop: 50, flex: 1, display: "flex", flexDirection: "column" }}>
        {children}
      </div>
    </div>
  );

  const NavBar = ({ title, back, onBack }) => (
    <div style={{ padding: "12px 24px 8px", display: "flex", alignItems: "center", gap: 12 }}>
      {back && (
        <button onClick={onBack} style={{
          background: "none", border: "none", color: "#FF4458", fontSize: 22,
          cursor: "pointer", padding: 0, lineHeight: 1,
        }}>‹</button>
      )}
      <span style={{ color: "#fff", fontWeight: 700, fontSize: 18, letterSpacing: -0.5 }}>{title}</span>
    </div>
  );

  // SPLASH
  if (screen === "splash") return (
    <Wrapper>
      <Phone>
        <div style={{
          flex: 1, display: "flex", flexDirection: "column",
          alignItems: "center", justifyContent: "center", gap: 24, padding: 40,
        }}>
          <div style={{
            width: 100, height: 100, borderRadius: 28,
            background: "linear-gradient(135deg, #FF4458, #FF6B35)",
            display: "flex", alignItems: "center", justifyContent: "center",
            fontSize: 50, boxShadow: "0 20px 60px rgba(255,68,88,0.4)",
          }}>🚪</div>
          <div style={{ textAlign: "center" }}>
            <div style={{ color: "#fff", fontSize: 42, fontWeight: 800, letterSpacing: -2, lineHeight: 1 }}>bail.</div>
            <div style={{ color: "#666", fontSize: 16, marginTop: 8, letterSpacing: 0.2 }}>no pressure. no drama.</div>
          </div>
          <div style={{ marginTop: 40, width: "100%", display: "flex", flexDirection: "column", gap: 12 }}>
            <button onClick={() => setScreen("home")} style={{
              background: "linear-gradient(135deg, #FF4458, #FF6B35)",
              border: "none", borderRadius: 16, padding: "18px 0",
              color: "#fff", fontSize: 17, fontWeight: 700, cursor: "pointer",
              boxShadow: "0 8px 30px rgba(255,68,88,0.35)",
            }}>Get Started</button>
            <button style={{
              background: "#1a1a1a", border: "1px solid #333",
              borderRadius: 16, padding: "18px 0",
              color: "#aaa", fontSize: 17, cursor: "pointer",
            }}>Sign In</button>
          </div>
          <div style={{ color: "#444", fontSize: 12, textAlign: "center", lineHeight: 1.6 }}>
            Everyone secretly votes. No blame. No awkward texts.
          </div>
        </div>
      </Phone>
    </Wrapper>
  );

  // HOME
  if (screen === "home") return (
    <Wrapper>
      <Phone>
        <div style={{ flex: 1, display: "flex", flexDirection: "column" }}>
          {/* Header */}
          <div style={{ padding: "16px 24px 0", display: "flex", justifyContent: "space-between", alignItems: "center" }}>
            <div>
              <div style={{ color: "#666", fontSize: 13 }}>Hey Joe 👋</div>
              <div style={{ color: "#fff", fontSize: 24, fontWeight: 800, letterSpacing: -1 }}>Your Plans</div>
            </div>
            <div style={{
              width: 42, height: 42, borderRadius: 14,
              background: "linear-gradient(135deg, #FF4458, #FF6B35)",
              display: "flex", alignItems: "center", justifyContent: "center",
              fontSize: 20, cursor: "pointer",
            }} onClick={() => { setCreateStep(1); setScreen("create"); }}>+</div>
          </div>

          {/* Tab */}
          <div style={{ padding: "16px 24px 8px", display: "flex", gap: 8 }}>
            {["Upcoming", "Past"].map((t, i) => (
              <div key={t} style={{
                padding: "8px 18px", borderRadius: 20,
                background: i === 0 ? "linear-gradient(135deg, #FF4458, #FF6B35)" : "#1a1a1a",
                color: i === 0 ? "#fff" : "#666",
                fontSize: 13, fontWeight: 600, cursor: "pointer",
              }}>{t}</div>
            ))}
          </div>

          {/* Events */}
          <div style={{ flex: 1, padding: "8px 24px", display: "flex", flexDirection: "column", gap: 12, overflowY: "auto" }}>
            {sampleEvents.map(ev => (
              <div key={ev.id} onClick={() => setScreen("event")} style={{
                background: "#141414", borderRadius: 20, padding: 20,
                border: "1px solid #222", cursor: "pointer",
                transition: "transform 0.1s",
              }}>
                <div style={{ display: "flex", justifyContent: "space-between", alignItems: "flex-start" }}>
                  <div>
                    <div style={{ color: "#fff", fontWeight: 700, fontSize: 17 }}>{ev.title}</div>
                    <div style={{ color: "#666", fontSize: 13, marginTop: 3 }}>{ev.time}</div>
                  </div>
                  <div style={{
                    background: ev.bails > 0 ? "rgba(255,68,88,0.15)" : "rgba(78,205,196,0.15)",
                    borderRadius: 10, padding: "4px 10px",
                    color: ev.bails > 0 ? "#FF4458" : "#4ECDC4",
                    fontSize: 12, fontWeight: 600,
                  }}>{ev.bails > 0 ? `${ev.bails} bailed` : "All in"}</div>
                </div>

                {/* Guest avatars */}
                <div style={{ marginTop: 14, display: "flex", alignItems: "center", gap: -6 }}>
                  {ev.guests.map((gid, i) => {
                    const g = friends.find(f => f.id === gid);
                    return (
                      <div key={gid} style={{
                        width: 32, height: 32, borderRadius: "50%",
                        background: g.color, color: "#000",
                        display: "flex", alignItems: "center", justifyContent: "center",
                        fontSize: 12, fontWeight: 700,
                        border: "2px solid #141414",
                        marginLeft: i > 0 ? -8 : 0, zIndex: ev.guests.length - i,
                        position: "relative",
                      }}>{g.avatar}</div>
                    );
                  })}
                  <div style={{ marginLeft: 12, color: "#555", fontSize: 12 }}>{ev.guests.length} invited</div>
                </div>

                {/* Bail-o-meter */}
                <div style={{ marginTop: 14 }}>
                  <div style={{ display: "flex", justifyContent: "space-between", marginBottom: 6 }}>
                    <div style={{ color: "#555", fontSize: 11 }}>BAIL-O-METER</div>
                    <div style={{ color: "#555", fontSize: 11 }}>{ev.bails}/{ev.threshold} to cancel</div>
                  </div>
                  <div style={{ height: 4, background: "#222", borderRadius: 4 }}>
                    <div style={{
                      height: "100%", borderRadius: 4,
                      width: `${(ev.bails / ev.threshold) * 100}%`,
                      background: "linear-gradient(90deg, #FF4458, #FF6B35)",
                    }} />
                  </div>
                </div>
              </div>
            ))}

            {/* Empty CTA */}
            <div onClick={() => { setCreateStep(1); setScreen("create"); }} style={{
              background: "#0f0f0f", borderRadius: 20, padding: 24,
              border: "1px dashed #2a2a2a", cursor: "pointer",
              display: "flex", flexDirection: "column", alignItems: "center", gap: 8,
            }}>
              <div style={{ fontSize: 28 }}>＋</div>
              <div style={{ color: "#444", fontSize: 14 }}>Create new plan</div>
            </div>
          </div>

          {/* Bottom Nav */}
          <div style={{
            height: 80, background: "#0f0f0f", borderTop: "1px solid #1a1a1a",
            display: "flex", justifyContent: "space-around", alignItems: "center",
            padding: "0 20px 16px",
          }}>
            {[["🏠","Home"],["👥","Friends"],["🔔","Alerts"],["👤","Profile"]].map(([icon, label], i) => (
              <div key={label} style={{ display: "flex", flexDirection: "column", alignItems: "center", gap: 3, cursor: "pointer" }}>
                <div style={{ fontSize: 20 }}>{icon}</div>
                <div style={{ color: i === 0 ? "#FF4458" : "#444", fontSize: 10, fontWeight: 600 }}>{label}</div>
              </div>
            ))}
          </div>
        </div>
      </Phone>
    </Wrapper>
  );

  // CREATE EVENT
  if (screen === "create") return (
    <Wrapper>
      <Phone>
        <NavBar title={createStep === 1 ? "New Plan" : createStep === 2 ? "Invite Friends" : "Bail Rules"} back onBack={() => createStep === 1 ? setScreen("home") : setCreateStep(s => s - 1)} />

        {/* Step indicator */}
        <div style={{ padding: "8px 24px", display: "flex", gap: 6 }}>
          {[1,2,3].map(s => (
            <div key={s} style={{
              height: 3, flex: 1, borderRadius: 3,
              background: s <= createStep ? "linear-gradient(90deg, #FF4458, #FF6B35)" : "#222",
            }} />
          ))}
        </div>

        <div style={{ flex: 1, padding: "16px 24px", display: "flex", flexDirection: "column", gap: 20 }}>
          {createStep === 1 && <>
            <div style={{ color: "#fff", fontSize: 22, fontWeight: 700, letterSpacing: -0.5 }}>What's the plan?</div>
            <div style={{ display: "flex", flexDirection: "column", gap: 12 }}>
              <div>
                <div style={{ color: "#666", fontSize: 12, marginBottom: 6, textTransform: "uppercase", letterSpacing: 1 }}>Event Name</div>
                <input value={eventTitle} onChange={e => setEventTitle(e.target.value)} style={{
                  width: "100%", background: "#141414", border: "1px solid #2a2a2a",
                  borderRadius: 14, padding: "14px 16px", color: "#fff",
                  fontSize: 16, outline: "none", boxSizing: "border-box",
                }} />
              </div>
              <div>
                <div style={{ color: "#666", fontSize: 12, marginBottom: 6, textTransform: "uppercase", letterSpacing: 1 }}>Date & Time</div>
                <input value={eventTime} onChange={e => setEventTime(e.target.value)} style={{
                  width: "100%", background: "#141414", border: "1px solid #2a2a2a",
                  borderRadius: 14, padding: "14px 16px", color: "#fff",
                  fontSize: 16, outline: "none", boxSizing: "border-box",
                }} />
              </div>
              <div>
                <div style={{ color: "#666", fontSize: 12, marginBottom: 6, textTransform: "uppercase", letterSpacing: 1 }}>Location (optional)</div>
                <input placeholder="Add a location..." style={{
                  width: "100%", background: "#141414", border: "1px solid #2a2a2a",
                  borderRadius: 14, padding: "14px 16px", color: "#fff",
                  fontSize: 16, outline: "none", boxSizing: "border-box",
                }} />
              </div>
            </div>
          </>}

          {createStep === 2 && <>
            <div style={{ color: "#fff", fontSize: 22, fontWeight: 700, letterSpacing: -0.5 }}>Who's invited?</div>
            <div style={{ display: "flex", flexDirection: "column", gap: 10 }}>
              {friends.map(f => (
                <div key={f.id} onClick={() => toggleGuest(f.id)} style={{
                  background: selectedGuests.includes(f.id) ? "#1a1a1a" : "#111",
                  border: selectedGuests.includes(f.id) ? "1px solid #FF4458" : "1px solid #222",
                  borderRadius: 16, padding: "14px 16px",
                  display: "flex", alignItems: "center", gap: 14, cursor: "pointer",
                }}>
                  <div style={{
                    width: 40, height: 40, borderRadius: "50%",
                    background: f.color, color: "#000",
                    display: "flex", alignItems: "center", justifyContent: "center",
                    fontWeight: 700, fontSize: 16,
                  }}>{f.avatar}</div>
                  <div style={{ color: "#fff", fontSize: 16, flex: 1 }}>{f.name}</div>
                  {selectedGuests.includes(f.id) && <div style={{ color: "#FF4458", fontSize: 20 }}>✓</div>}
                </div>
              ))}
            </div>
          </>}

          {createStep === 3 && <>
            <div style={{ color: "#fff", fontSize: 22, fontWeight: 700, letterSpacing: -0.5 }}>Set bail rules</div>
            <div style={{ color: "#666", fontSize: 14, marginTop: -12 }}>How many bails to auto-cancel?</div>
            <div style={{ display: "flex", flexDirection: "column", gap: 10 }}>
              {[
                { key: "all", label: "Everyone bails", desc: "100% must opt out to cancel" },
                { key: "majority", label: "Majority bails", desc: "More than half opt out" },
                { key: "any", label: "Anyone bails", desc: "Even one bail cancels it" },
              ].map(opt => (
                <div key={opt.key} onClick={() => setThreshold(opt.key)} style={{
                  background: threshold === opt.key ? "#1a1a1a" : "#111",
                  border: threshold === opt.key ? "1px solid #FF4458" : "1px solid #222",
                  borderRadius: 16, padding: "16px 18px", cursor: "pointer",
                }}>
                  <div style={{ color: "#fff", fontWeight: 600, fontSize: 15 }}>{opt.label}</div>
                  <div style={{ color: "#555", fontSize: 12, marginTop: 3 }}>{opt.desc}</div>
                </div>
              ))}
            </div>
            <div style={{
              background: "rgba(255,68,88,0.08)", borderRadius: 14, padding: 14,
              border: "1px solid rgba(255,68,88,0.15)",
            }}>
              <div style={{ color: "#FF4458", fontSize: 12, fontWeight: 600 }}>🔒 FULLY ANONYMOUS</div>
              <div style={{ color: "#666", fontSize: 12, marginTop: 4, lineHeight: 1.5 }}>
                Nobody ever sees who voted to bail — not even you. The app only shows the final outcome.
              </div>
            </div>
          </>}
        </div>

        <div style={{ padding: "0 24px 40px" }}>
          <button onClick={() => createStep < 3 ? setCreateStep(s => s + 1) : setScreen("event")} style={{
            width: "100%", background: "linear-gradient(135deg, #FF4458, #FF6B35)",
            border: "none", borderRadius: 16, padding: "18px 0",
            color: "#fff", fontSize: 17, fontWeight: 700, cursor: "pointer",
            boxShadow: "0 8px 30px rgba(255,68,88,0.3)",
          }}>{createStep < 3 ? "Continue →" : "Send Invites 🚀"}</button>
        </div>
      </Phone>
    </Wrapper>
  );

  // EVENT DETAIL
  if (screen === "event") return (
    <Wrapper>
      <Phone>
        <NavBar title="" back onBack={() => setScreen("home")} />
        <div style={{ flex: 1, padding: "0 24px", display: "flex", flexDirection: "column", gap: 20 }}>
          <div>
            <div style={{ color: "#FF4458", fontSize: 12, fontWeight: 600, letterSpacing: 1, textTransform: "uppercase" }}>Saturday · 7:00 PM</div>
            <div style={{ color: "#fff", fontSize: 28, fontWeight: 800, letterSpacing: -1, marginTop: 4 }}>Dinner at Zinc</div>
            <div style={{ color: "#555", fontSize: 14, marginTop: 4 }}>📍 Zinc Restaurant, New Haven</div>
          </div>

          {/* Guests */}
          <div style={{ background: "#141414", borderRadius: 20, padding: 18, border: "1px solid #222" }}>
            <div style={{ color: "#666", fontSize: 12, fontWeight: 600, textTransform: "uppercase", letterSpacing: 1, marginBottom: 12 }}>Invited</div>
            {[1,2,3,4].map(gid => {
              const g = friends.find(f => f.id === gid);
              return (
                <div key={gid} style={{ display: "flex", alignItems: "center", gap: 12, marginBottom: 12 }}>
                  <div style={{
                    width: 36, height: 36, borderRadius: "50%",
                    background: g.color, color: "#000",
                    display: "flex", alignItems: "center", justifyContent: "center",
                    fontWeight: 700,
                  }}>{g.avatar}</div>
                  <div style={{ color: "#fff", flex: 1 }}>{g.name}</div>
                  <div style={{ color: "#444", fontSize: 12 }}>voted ✓</div>
                </div>
              );
            })}
          </div>

          {/* Bail-o-meter */}
          <div style={{ background: "#141414", borderRadius: 20, padding: 18, border: "1px solid #222" }}>
            <div style={{ display: "flex", justifyContent: "space-between", marginBottom: 10 }}>
              <div style={{ color: "#666", fontSize: 12, fontWeight: 600, textTransform: "uppercase", letterSpacing: 1 }}>Bail-o-meter</div>
              <div style={{ color: "#FF4458", fontSize: 12, fontWeight: 600 }}>2 of 3 to cancel</div>
            </div>
            <div style={{ height: 8, background: "#222", borderRadius: 8 }}>
              <div style={{
                height: "100%", width: "66%", borderRadius: 8,
                background: "linear-gradient(90deg, #FF4458, #FF6B35)",
                boxShadow: "0 0 12px rgba(255,68,88,0.4)",
              }} />
            </div>
            <div style={{ color: "#555", fontSize: 12, marginTop: 8 }}>2 anonymous bails recorded</div>
          </div>

          {/* CTA */}
          <button onClick={() => { setVoted(null); setShowResult(false); setScreen("vote"); }} style={{
            background: "linear-gradient(135deg, #FF4458, #FF6B35)",
            border: "none", borderRadius: 16, padding: "18px 0",
            color: "#fff", fontSize: 17, fontWeight: 700, cursor: "pointer",
            boxShadow: "0 8px 30px rgba(255,68,88,0.3)",
          }}>Cast Your Vote 🗳️</button>

          <div style={{ color: "#444", fontSize: 12, textAlign: "center", lineHeight: 1.6 }}>
            Your vote is 100% anonymous. Nobody will ever know what you chose.
          </div>
        </div>
      </Phone>
    </Wrapper>
  );

  // VOTE SCREEN
  if (screen === "vote") return (
    <Wrapper>
      <Phone>
        <NavBar title="" back onBack={() => setScreen("event")} />
        <div style={{
          flex: 1, padding: "0 24px 40px", display: "flex",
          flexDirection: "column", alignItems: "center", justifyContent: "center", gap: 24,
        }}>
          {!showResult ? <>
            <div style={{ textAlign: "center" }}>
              <div style={{ fontSize: 48, marginBottom: 12 }}>{voted === null ? "🤔" : voted === "in" ? "🙌" : "🚪"}</div>
              <div style={{ color: "#fff", fontSize: 24, fontWeight: 800, letterSpacing: -0.5 }}>Dinner at Zinc</div>
              <div style={{ color: "#666", fontSize: 14, marginTop: 4 }}>Saturday · 7:00 PM</div>
              <div style={{ color: "#555", fontSize: 13, marginTop: 16, lineHeight: 1.6 }}>
                Your vote is completely secret.<br />No one will ever know what you chose.
              </div>
            </div>

            <div style={{ width: "100%", display: "flex", flexDirection: "column", gap: 12 }}>
              <button onClick={() => handleVote("in")} style={{
                background: voted === "in" ? "linear-gradient(135deg, #4ECDC4, #2EC4B6)" : "#141414",
                border: voted === "in" ? "none" : "1px solid #2a2a2a",
                borderRadius: 20, padding: "22px 0",
                color: "#fff", fontSize: 18, fontWeight: 700, cursor: "pointer",
                transition: "all 0.2s",
                boxShadow: voted === "in" ? "0 8px 30px rgba(78,205,196,0.3)" : "none",
              }}>
                <div>🙌 I'm In</div>
                <div style={{ fontSize: 12, fontWeight: 400, color: voted === "in" ? "rgba(255,255,255,0.7)" : "#555", marginTop: 4 }}>Keep the plan</div>
              </button>

              <button onClick={() => handleVote("bail")} style={{
                background: voted === "bail" ? "linear-gradient(135deg, #FF4458, #FF6B35)" : "#141414",
                border: voted === "bail" ? "none" : "1px solid #2a2a2a",
                borderRadius: 20, padding: "22px 0",
                color: "#fff", fontSize: 18, fontWeight: 700, cursor: "pointer",
                transition: "all 0.2s",
                boxShadow: voted === "bail" ? "0 8px 30px rgba(255,68,88,0.3)" : "none",
              }}>
                <div>🚪 I'd Bail</div>
                <div style={{ fontSize: 12, fontWeight: 400, color: voted === "bail" ? "rgba(255,255,255,0.7)" : "#555", marginTop: 4 }}>Secretly opt out</div>
              </button>
            </div>

            <div style={{ color: "#333", fontSize: 11, textAlign: "center" }}>
              🔒 Encrypted · Anonymous · Nobody sees this
            </div>
          </> : <>
            <div style={{ textAlign: "center" }}>
              <div style={{ fontSize: 64, marginBottom: 16 }}>
                {voted === "bail" ? "🚪" : "🙌"}
              </div>
              <div style={{ color: "#fff", fontSize: 22, fontWeight: 800 }}>
                {voted === "bail" ? "Bail recorded." : "You're in!"}
              </div>
              <div style={{ color: "#555", fontSize: 14, marginTop: 8, lineHeight: 1.7 }}>
                {voted === "bail"
                  ? "Your secret is safe.\nWe'll let you know if the plan gets cancelled."
                  : "Nice! We'll notify you if anything changes."}
              </div>
            </div>

            <div style={{
              background: "#141414", borderRadius: 20, padding: 20,
              border: "1px solid #222", width: "100%", textAlign: "center",
            }}>
              <div style={{ color: "#444", fontSize: 12, marginBottom: 8 }}>CURRENT STATUS</div>
              <div style={{ color: "#FF4458", fontSize: 16, fontWeight: 700 }}>2 of 3 bails needed</div>
              <div style={{ color: "#555", fontSize: 12, marginTop: 4 }}>Still on — for now 👀</div>
            </div>

            <button onClick={() => setScreen("home")} style={{
              width: "100%", background: "#1a1a1a", border: "1px solid #333",
              borderRadius: 16, padding: "16px 0", color: "#fff",
              fontSize: 16, cursor: "pointer",
            }}>Back to Plans</button>
          </>}
        </div>
      </Phone>
    </Wrapper>
  );

  // CANCELLED
  if (screen === "cancelled") return (
    <Wrapper>
      <Phone bg="#080808">
        <div style={{
          flex: 1, display: "flex", flexDirection: "column",
          alignItems: "center", justifyContent: "center", gap: 20, padding: 40,
        }}>
          <div style={{ fontSize: 80 }}>💀</div>
          <div style={{ textAlign: "center" }}>
            <div style={{ color: "#FF4458", fontSize: 32, fontWeight: 800, letterSpacing: -1 }}>It's dead.</div>
            <div style={{ color: "#fff", fontSize: 20, fontWeight: 700, marginTop: 4 }}>Dinner at Zinc</div>
            <div style={{ color: "#555", fontSize: 14, marginTop: 12, lineHeight: 1.7 }}>
              Enough people bailed.<br />Plans have been cancelled.<br />No names. No blame. No drama.
            </div>
          </div>
          <div style={{
            background: "#111", borderRadius: 16, padding: "14px 20px",
            border: "1px solid #222", textAlign: "center",
          }}>
            <div style={{ color: "#444", fontSize: 11, textTransform: "uppercase", letterSpacing: 1 }}>Sent to everyone</div>
            <div style={{ color: "#aaa", fontSize: 14, marginTop: 6, fontStyle: "italic" }}>
              "Hey, plans fell through for Saturday. Maybe next time! 🤷"
            </div>
          </div>
          <button onClick={() => setScreen("home")} style={{
            width: "100%", background: "linear-gradient(135deg, #FF4458, #FF6B35)",
            border: "none", borderRadius: 16, padding: "18px 0",
            color: "#fff", fontSize: 17, fontWeight: 700, cursor: "pointer",
          }}>Back to Home</button>
        </div>
      </Phone>
    </Wrapper>
  );

  return null;
}

function Wrapper({ children }) {
  return (
    <div style={{
      minHeight: "100vh", background: "#050505",
      display: "flex", flexDirection: "column", alignItems: "center",
      justifyContent: "flex-start", padding: "40px 20px",
      gap: 24,
    }}>
      {/* Screen nav */}
      <div style={{ display: "flex", gap: 8, flexWrap: "wrap", justifyContent: "center" }}>
        {[
          ["splash","Splash"],["home","Home"],["create","Create"],
          ["event","Event"],["vote","Vote"],["cancelled","Cancelled"],
        ].map(([key, label]) => (
          <button key={key} style={{
            background: "#111", border: "1px solid #222",
            borderRadius: 20, padding: "6px 14px", color: "#666",
            fontSize: 12, cursor: "pointer",
          }}
          onClick={() => {
            if (key === "vote") { window.location.reload?.(); }
          }}
          >{label}</button>
        ))}
      </div>
      <div style={{ color: "#333", fontSize: 11 }}>↑ tap buttons above OR interact with the phone below</div>
      {children}
    </div>
  );
}
