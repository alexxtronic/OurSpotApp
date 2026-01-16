
import { useState } from 'react'
import Aurora from './components/Aurora/Aurora'
import ShinyText from './components/ShinyText/ShinyText'
import CircularText from './components/CircularText/CircularText'
import ElectricBorder from './components/ElectricBorder/ElectricBorder'
import './index.css'

function App() {
    return (
        <div className="app-container">
            {/* Background - Aurora */}
            <div className="background-wrapper">
                <Aurora
                    colorStops={["#FF6B6B", "#FB923C", "#F97316"]} // Warm sunset/social vibes
                    blend={0.7}
                    amplitude={1.2}
                    speed={0.5}
                />
            </div>

            {/* Noise Overlay */}
            <div className="noise"></div>

            {/* Navigation */}
            <nav className="nav">
                <div className="nav-container">
                    <div className="logo">
                        <img src="/logo.png" alt="OurSpot" className="logo-img" />
                        <span className="logo-text">OurSpot</span>
                    </div>
                    <a href="#download" className="nav-cta">Get the App</a>
                </div>
            </nav>

            {/* Hero Section */}
            <section className="hero">
                <div className="hero-content">
                    <div className="badge">
                        <span className="badge-dot"></span>
                        Now Available on iOS
                    </div>

                    <div className="hero-title-wrapper">
                        <h1 className="sr-only">The Meetup App You've Been Waiting For.</h1>
                        <ShinyText
                            text="The Meetup App You've Been Waiting For"
                            speed={3}
                            delay={0.1}
                            color="#e2a765"
                            spread={175}
                            className="heading-large"
                        />
                    </div>

                    <p className="hero-subtitle">
                        Make new friends anywhere in the world.<br />
                        <span className="text-highlight">Apply for free membership now:</span>
                    </p>

                    <div className="hero-ctas">
                        <a href="https://docs.google.com/forms/d/e/1FAIpQLSfRdjusAZd9ItfX9G538RGfOZwrA_dMMZja8USxeAeTafi0Xw/viewform?fbzx=-547562085666947481" className="btn btn-primary" target="_blank" rel="noopener noreferrer">
                            Join the waitlist
                        </a>
                    </div>
                </div>

                {/* Phone Mockup */}
                <div className="phone-mockup">
                    <div className="phone-frame">
                        <div className="phone-screen">
                            <div className="map-bg"></div>

                            {/* Pins */}
                            <div className="plan-pin" style={{ top: '18%', left: '22%' }}>
                                <div className="pin-attendees">
                                    <img src="/profile-1.png" alt="" /><img src="/profile-2.png" alt="" /><img src="/profile-3.png" alt="" />
                                </div>
                                <div className="pin-label">🔥 Party</div>
                            </div>
                            <div className="plan-pin" style={{ top: '35%', left: '65%' }}>
                                <div className="pin-attendees">
                                    <img src="/profile-2.png" alt="" /><img src="/profile-4.png" alt="" />
                                </div>
                                <div className="pin-label">🌊 Chilling</div>
                            </div>
                            <div className="plan-pin" style={{ top: '55%', left: '30%' }}>
                                <div className="pin-attendees">
                                    <img src="/profile-3.png" alt="" /><img src="/profile-1.png" alt="" /><img src="/profile-2.png" alt="" />
                                </div>
                                <div className="pin-label">🍕 Pizza</div>
                            </div>

                            {/* Event Card */}
                            <div className="event-card-preview">
                                <div className="event-attendees">
                                    <img src="/profile-1.png" alt="" /><img src="/profile-2.png" alt="" /><img src="/profile-3.png" alt="" />
                                </div>
                                <div className="event-info">
                                    <div className="event-name">Pizza Night 🍕</div>
                                    <div className="event-meta">8 PM · 4 going</div>
                                </div>
                                <div className="event-join">Join</div>
                            </div>

                            {/* Nav Bar */}
                            <div className="nav-bar">
                                <div className="nav-item active">
                                    <svg viewBox="0 0 24 24" fill="currentColor"><path d="M12 2C8.13 2 5 5.13 5 9c0 5.25 7 13 7 13s7-7.75 7-13c0-3.87-3.13-7-7-7zm0 9.5c-1.38 0-2.5-1.12-2.5-2.5s1.12-2.5 2.5-2.5 2.5 1.12 2.5 2.5-1.12 2.5-2.5 2.5z" /></svg>
                                </div>
                                <div className="nav-item">
                                    <svg viewBox="0 0 24 24" fill="currentColor"><path d="M21 6h-2v9H6v2c0 .55.45 1 1 1h11l4 4V7c0-.55-.45-1-1-1zm-4 6V3c0-.55-.45-1-1-1H3c-.55 0-1 .45-1 1v14l4-4h10c.55 0 1-.45 1-1z" /></svg>
                                </div>
                                <div className="nav-item nav-plus">
                                    <svg viewBox="0 0 24 24" fill="currentColor"><path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm5 11h-4v4h-2v-4H7v-2h4V7h2v4h4v2z" /></svg>
                                </div>
                                <div className="nav-item">
                                    <svg viewBox="0 0 24 24" fill="currentColor"><path d="M3 13h2v-2H3v2zm0 4h2v-2H3v2zm0-8h2V7H3v2zm4 4h14v-2H7v2zm0 4h14v-2H7v2zM7 7v2h14V7H7z" /></svg>
                                </div>
                                <div className="nav-item">
                                    <svg viewBox="0 0 24 24" fill="currentColor"><path d="M12 12c2.21 0 4-1.79 4-4s-1.79-4-4-4-4 1.79-4 4 1.79 4 4 4zm0 2c-2.67 0-8 1.34-8 4v2h16v-2c0-2.66-5.33-4-8-4z" /></svg>
                                </div>
                            </div>

                            {/* Speech Bubbles Layer */}
                            <SpeechBubbles />
                        </div>
                    </div>
                    <div className="phone-glow"></div>
                </div>
            </section>

            {/* App Showcase Section */}
            <section className="showcase-section">
                <div className="showcase-preview-wrapper">
                    <img src="/showcase-diagram.png" alt="OurSpot App Features" className="app-screen-img showcase-diagram" />


                </div>
            </section>

            {/* Statements */}
            <section className="statements">
                <div className="statement-card">
                    <span className="statement-icon">🔥</span>
                    <h2>Stop asking "wyd?"</h2>
                    <p>Send a link & organize all your friends in one place! No more hopping from IG to Snap to WhatsApp.</p>
                </div>
                <div className="statement-card">
                    <span className="statement-icon">🙌</span>
                    <h2>Always have a crew</h2>
                    <p>When your friends are too busy, throw a pin on the public map. Go out with some new friends, verified by our community.</p>
                </div>
                <div className="statement-card">
                    <span className="statement-icon">💀</span>
                    <h2>No creeps allowed</h2>
                    <p>Know exactly who you're meeting beforehand. Users are reviewed by the community, just like your Uber driver.</p>
                </div>
            </section>

            {/* Big Statement */}
            <section className="big-statement">
                <h2 className="big-text">
                    Your friends are making plans on <span className="highlight">OurSpot</span> right now.
                    <br />
                    <span className="smaller">Don't be the last to know.</span>
                </h2>
            </section>

            {/* Social Proof */}
            <section className="proof">
                <div className="proof-stats">
                    <div className="stat">
                        <span className="stat-number">10K+</span>
                        <span className="stat-label">Plans Created</span>
                    </div>
                    <div className="stat">
                        <span className="stat-number">50K+</span>
                        <span className="stat-label">Hangouts Happened</span>
                    </div>
                    <div className="stat">
                        <span className="stat-number">0</span>
                        <span className="stat-label">Lonely Nights</span>
                    </div>
                </div>
            </section>

            {/* Final CTA */}
            <section className="final-cta" id="download">
                <div className="cta-content">
                    <h2 className="cta-title">
                        Ready to Actually<br />
                        <span className="gradient-text">Have a Social Life?</span>
                    </h2>
                    <p className="cta-subtitle">Download OurSpot. It's free. Your friends are waiting.</p>

                    <a href="https://docs.google.com/forms/d/e/1FAIpQLSfRdjusAZd9ItfX9G538RGfOZwrA_dMMZja8USxeAeTafi0Xw/viewform?fbzx=-547562085666947481" className="btn btn-primary btn-large" target="_blank" rel="noopener noreferrer">
                        Join the waitlist
                    </a>
                    <p className="cta-note">Spots opening weekly</p>
                </div>
            </section>

            {/* Footer */}
            <footer className="footer">
                <div className="footer-content">
                    <div className="footer-brand">
                        <img src="/logo.png" alt="OurSpot" className="logo-img" />
                        <span className="logo-text">OurSpot</span>
                    </div>
                    <div className="footer-links">
                        <a href="https://alexxtronic.github.io/ourspot-legal/privacy-policy.html">Privacy</a>
                        <a href="https://alexxtronic.github.io/ourspot-legal/terms-of-service.html">Terms</a>
                        <a href="mailto:ourspothelper@gmail.com">Support</a>
                    </div>
                    <p className="footer-copy">© 2025 OurSpot. Made for people who touch grass.</p>
                </div>
            </footer>
        </div>
    )
}

export default App
