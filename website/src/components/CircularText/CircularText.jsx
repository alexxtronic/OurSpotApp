import React, { useEffect, useState } from 'react';
import './CircularText.css';

const CircularText = ({
    text = 'REACT BITS',
    onHover = 'speedUp',
    spinDuration = 20,
    className = '',
}) => {
    const letters = text.split('');
    const deg = 360 / letters.length;

    return (
        <div
            className={`circular-text ${className}`}
            style={{
                '--spin-duration': `${spinDuration}s`,
            }}
            onMouseEnter={() => {
                if (onHover === 'pause') {
                    // implementation allows css to handle this
                }
            }}
            onMouseLeave={() => {
                // implementation allows css to handle this
            }}
        >
            <div className="circular-text-spin">
                {letters.map((letter, i) => (
                    <span
                        key={i}
                        style={{
                            transform: `rotate(${deg * i}deg) translateY(-6rem)`, // Adjust radius
                        }}
                    >
                        {letter}
                    </span>
                ))}
            </div>
        </div>
    );
};

export default CircularText;
