import { useState, useEffect, useRef } from 'react';

const CountUp = ({ end, suffix = '', duration = 3000 }) => {
    const [count, setCount] = useState(0);
    const [hasStarted, setHasStarted] = useState(false);
    const ref = useRef(null);

    useEffect(() => {
        const observer = new IntersectionObserver(
            ([entry]) => {
                if (entry.isIntersecting && !hasStarted) {
                    setHasStarted(true);
                }
            },
            { threshold: 0.5 }
        );

        if (ref.current) {
            observer.observe(ref.current);
        }

        return () => observer.disconnect();
    }, [hasStarted]);

    useEffect(() => {
        if (!hasStarted) return;

        const startTime = Date.now();
        const endTime = startTime + duration;

        const animate = () => {
            const now = Date.now();
            const progress = Math.min((now - startTime) / duration, 1);

            // Ease out cubic for smooth deceleration
            const eased = 1 - Math.pow(1 - progress, 3);
            const currentCount = Math.floor(eased * end);

            setCount(currentCount);

            if (progress < 1) {
                requestAnimationFrame(animate);
            }
        };

        requestAnimationFrame(animate);
    }, [hasStarted, end, duration]);

    // Format number with K suffix
    const formatNumber = (num) => {
        if (end >= 1000) {
            return Math.floor(num / 1000) + 'K';
        }
        return num.toString();
    };

    return (
        <span ref={ref} className="stat-number">
            {formatNumber(count)}{suffix}
        </span>
    );
};

export default CountUp;
