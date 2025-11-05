// ================================
// MOBILE MENU TOGGLE
// ================================

const mobileMenuBtn = document.getElementById('mobileMenuBtn');
const mobileMenu = document.getElementById('mobileMenu');

if (mobileMenuBtn && mobileMenu) {
    mobileMenuBtn.addEventListener('click', () => {
        mobileMenu.classList.toggle('active');

        // Animate hamburger to X
        const spans = mobileMenuBtn.querySelectorAll('span');
        if (mobileMenu.classList.contains('active')) {
            spans[0].style.transform = 'rotate(45deg) translateY(8px)';
            spans[1].style.opacity = '0';
            spans[2].style.transform = 'rotate(-45deg) translateY(-8px)';
        } else {
            spans[0].style.transform = 'none';
            spans[1].style.opacity = '1';
            spans[2].style.transform = 'none';
        }
    });

    // Close mobile menu when clicking a link
    const mobileMenuLinks = mobileMenu.querySelectorAll('a');
    mobileMenuLinks.forEach(link => {
        link.addEventListener('click', () => {
            mobileMenu.classList.remove('active');
            const spans = mobileMenuBtn.querySelectorAll('span');
            spans[0].style.transform = 'none';
            spans[1].style.opacity = '1';
            spans[2].style.transform = 'none';
        });
    });
}


// ================================
// SMOOTH SCROLL FOR ANCHOR LINKS
// ================================

document.querySelectorAll('a[href^="#"]').forEach(anchor => {
    anchor.addEventListener('click', function (e) {
        const href = this.getAttribute('href');

        // Don't prevent default for empty hash
        if (href === '#') {
            e.preventDefault();
            return;
        }

        const target = document.querySelector(href);
        if (target) {
            e.preventDefault();
            const navHeight = document.querySelector('.navbar').offsetHeight;
            const targetPosition = target.offsetTop - navHeight;

            window.scrollTo({
                top: targetPosition,
                behavior: 'smooth'
            });
        }
    });
});


// ================================
// INTERSECTION OBSERVER FOR ANIMATIONS
// ================================

const observerOptions = {
    threshold: 0.1,
    rootMargin: '0px 0px -100px 0px'
};

const observerCallback = (entries) => {
    entries.forEach(entry => {
        if (entry.isIntersecting) {
            entry.target.style.opacity = '1';
            entry.target.style.transform = 'translateY(0)';
        }
    });
};

const observer = new IntersectionObserver(observerCallback, observerOptions);

// Observe all sections for fade-in animation
const sections = document.querySelectorAll(
    '.problem-section, .features-section, .how-it-works, ' +
    '.comparison-section, .use-cases, .testimonials, ' +
    '.technical-section, .pricing-section, .faq-section'
);

sections.forEach(section => {
    section.style.opacity = '0';
    section.style.transform = 'translateY(30px)';
    section.style.transition = 'opacity 0.8s ease, transform 0.8s ease';
    observer.observe(section);
});


// ================================
// NAVBAR SHADOW ON SCROLL
// ================================

const navbar = document.querySelector('.navbar');
let lastScroll = 0;

window.addEventListener('scroll', () => {
    const currentScroll = window.pageYOffset;

    if (currentScroll > 50) {
        navbar.style.boxShadow = '0 4px 20px rgba(108, 92, 231, 0.15)';
    } else {
        navbar.style.boxShadow = '0 2px 8px rgba(108, 92, 231, 0.1)';
    }

    lastScroll = currentScroll;
});


// ================================
// ANIMATED COUNTER FOR STATS
// ================================

const animateCounter = (element, target, duration = 2000) => {
    const start = 0;
    const increment = target / (duration / 16); // 60fps
    let current = start;

    const updateCounter = () => {
        current += increment;
        if (current < target) {
            element.textContent = Math.floor(current).toLocaleString() + '+';
            requestAnimationFrame(updateCounter);
        } else {
            element.textContent = target.toLocaleString() + '+';
        }
    };

    updateCounter();
};

// Observe stats section
const statsSection = document.querySelector('.social-proof');
if (statsSection) {
    const statsObserver = new IntersectionObserver((entries) => {
        entries.forEach(entry => {
            if (entry.isIntersecting) {
                const statNumbers = entry.target.querySelectorAll('.stat-number');

                // Animate each stat number
                statNumbers.forEach(statNumber => {
                    const text = statNumber.textContent;
                    const number = parseInt(text.replace(/,|\+/g, ''));
                    animateCounter(statNumber, number);
                });

                statsObserver.unobserve(entry.target);
            }
        });
    }, { threshold: 0.5 });

    statsObserver.observe(statsSection);
}


// ================================
// MINI KANBAN ANIMATION (Hero Section)
// ================================

const miniKanban = document.querySelector('.mini-kanban');

if (miniKanban) {
    // Randomly move a card every few seconds for demo effect
    setInterval(() => {
        const columns = miniKanban.querySelectorAll('.mini-column');
        if (columns.length < 2) return;

        // Pick a random source column
        const sourceIndex = Math.floor(Math.random() * columns.length);
        const sourceColumn = columns[sourceIndex];
        const cards = sourceColumn.querySelectorAll('.mini-card');

        if (cards.length === 0) return;

        // Pick a random card
        const cardIndex = Math.floor(Math.random() * cards.length);
        const card = cards[cardIndex];

        // Pick a random target column (different from source)
        let targetIndex;
        do {
            targetIndex = Math.floor(Math.random() * columns.length);
        } while (targetIndex === sourceIndex);
        const targetColumn = columns[targetIndex];

        // Animate the move
        card.style.transition = 'all 0.5s ease';
        card.style.opacity = '0';
        card.style.transform = 'translateX(20px)';

        setTimeout(() => {
            targetColumn.appendChild(card);
            setTimeout(() => {
                card.style.opacity = '1';
                card.style.transform = 'translateX(0)';
            }, 50);
        }, 500);

    }, 5000); // Move a card every 5 seconds
}


// ================================
// FAQ ACCORDION (Optional Enhancement)
// ================================

const faqItems = document.querySelectorAll('.faq-item');

faqItems.forEach(item => {
    const question = item.querySelector('h3');
    const answer = item.querySelector('p');

    if (question && answer) {
        // Start with collapsed state (optional)
        // answer.style.maxHeight = '0';
        // answer.style.overflow = 'hidden';
        // answer.style.transition = 'max-height 0.3s ease';

        question.style.cursor = 'pointer';
        question.style.userSelect = 'none';

        question.addEventListener('click', () => {
            // Toggle answer visibility
            // Uncomment below for accordion behavior
            /*
            if (answer.style.maxHeight === '0px') {
                answer.style.maxHeight = answer.scrollHeight + 'px';
            } else {
                answer.style.maxHeight = '0';
            }
            */
        });
    }
});


// ================================
// CTA BUTTON HOVER EFFECTS
// ================================

const ctaButtons = document.querySelectorAll('.btn-primary');

ctaButtons.forEach(button => {
    button.addEventListener('mouseenter', (e) => {
        const ripple = document.createElement('span');
        ripple.style.position = 'absolute';
        ripple.style.width = '20px';
        ripple.style.height = '20px';
        ripple.style.background = 'rgba(255, 255, 255, 0.5)';
        ripple.style.borderRadius = '50%';
        ripple.style.transform = 'scale(0)';
        ripple.style.animation = 'ripple 0.6s ease-out';
        ripple.style.pointerEvents = 'none';

        const rect = button.getBoundingClientRect();
        ripple.style.left = (e.clientX - rect.left - 10) + 'px';
        ripple.style.top = (e.clientY - rect.top - 10) + 'px';

        if (button.style.position !== 'absolute' && button.style.position !== 'relative') {
            button.style.position = 'relative';
            button.style.overflow = 'hidden';
        }

        button.appendChild(ripple);

        setTimeout(() => {
            ripple.remove();
        }, 600);
    });
});

// Add ripple animation to CSS dynamically
const style = document.createElement('style');
style.textContent = `
    @keyframes ripple {
        to {
            transform: scale(4);
            opacity: 0;
        }
    }
`;
document.head.appendChild(style);


// ================================
// PRICING CARD HOVER TILT EFFECT
// ================================

const pricingCards = document.querySelectorAll('.pricing-card');

pricingCards.forEach(card => {
    card.addEventListener('mousemove', (e) => {
        const rect = card.getBoundingClientRect();
        const x = e.clientX - rect.left;
        const y = e.clientY - rect.top;

        const centerX = rect.width / 2;
        const centerY = rect.height / 2;

        const rotateX = (y - centerY) / 20;
        const rotateY = (centerX - x) / 20;

        card.style.transform = `perspective(1000px) rotateX(${rotateX}deg) rotateY(${rotateY}deg) translateY(-5px)`;
    });

    card.addEventListener('mouseleave', () => {
        card.style.transform = '';
    });
});


// ================================
// EASTER EGG: KONAMI CODE
// ================================

let konamiCode = [];
const konamiSequence = [
    'ArrowUp', 'ArrowUp', 'ArrowDown', 'ArrowDown',
    'ArrowLeft', 'ArrowRight', 'ArrowLeft', 'ArrowRight',
    'b', 'a'
];

document.addEventListener('keydown', (e) => {
    konamiCode.push(e.key);
    konamiCode = konamiCode.slice(-konamiSequence.length);

    if (konamiCode.join('') === konamiSequence.join('')) {
        // Easter egg activated!
        document.body.style.animation = 'rainbow 2s linear infinite';

        const style = document.createElement('style');
        style.textContent = `
            @keyframes rainbow {
                0% { filter: hue-rotate(0deg); }
                100% { filter: hue-rotate(360deg); }
            }
        `;
        document.head.appendChild(style);

        setTimeout(() => {
            document.body.style.animation = '';
        }, 5000);

        console.log('🎉 You found the easter egg! Enjoy the rainbow!');
    }
});


// ================================
// SCROLL PROGRESS INDICATOR
// ================================

const createScrollProgress = () => {
    const progressBar = document.createElement('div');
    progressBar.style.position = 'fixed';
    progressBar.style.top = '0';
    progressBar.style.left = '0';
    progressBar.style.width = '0%';
    progressBar.style.height = '3px';
    progressBar.style.background = 'linear-gradient(90deg, #667eea 0%, #764ba2 100%)';
    progressBar.style.zIndex = '9999';
    progressBar.style.transition = 'width 0.1s ease';

    document.body.appendChild(progressBar);

    window.addEventListener('scroll', () => {
        const windowHeight = document.documentElement.scrollHeight - document.documentElement.clientHeight;
        const scrolled = (window.pageYOffset / windowHeight) * 100;
        progressBar.style.width = scrolled + '%';
    });
};

createScrollProgress();


// ================================
// LAZY LOAD IMAGES (If Any)
// ================================

if ('IntersectionObserver' in window) {
    const imageObserver = new IntersectionObserver((entries) => {
        entries.forEach(entry => {
            if (entry.isIntersecting) {
                const img = entry.target;
                if (img.dataset.src) {
                    img.src = img.dataset.src;
                    img.removeAttribute('data-src');
                }
                imageObserver.unobserve(img);
            }
        });
    });

    const lazyImages = document.querySelectorAll('img[data-src]');
    lazyImages.forEach(img => imageObserver.observe(img));
}


// ================================
// COPY CODE SNIPPET FUNCTIONALITY
// ================================

const codeBlocks = document.querySelectorAll('.code-content');

codeBlocks.forEach(block => {
    const copyButton = document.createElement('button');
    copyButton.textContent = 'Copy';
    copyButton.style.position = 'absolute';
    copyButton.style.top = '1rem';
    copyButton.style.right = '1rem';
    copyButton.style.padding = '0.5rem 1rem';
    copyButton.style.background = 'rgba(255, 255, 255, 0.1)';
    copyButton.style.color = 'white';
    copyButton.style.border = '1px solid rgba(255, 255, 255, 0.2)';
    copyButton.style.borderRadius = '4px';
    copyButton.style.cursor = 'pointer';
    copyButton.style.fontSize = '0.875rem';
    copyButton.style.transition = 'all 0.2s ease';

    copyButton.addEventListener('mouseenter', () => {
        copyButton.style.background = 'rgba(255, 255, 255, 0.2)';
    });

    copyButton.addEventListener('mouseleave', () => {
        copyButton.style.background = 'rgba(255, 255, 255, 0.1)';
    });

    copyButton.addEventListener('click', () => {
        const code = block.textContent;
        navigator.clipboard.writeText(code).then(() => {
            copyButton.textContent = '✓ Copied!';
            copyButton.style.background = '#00b894';

            setTimeout(() => {
                copyButton.textContent = 'Copy';
                copyButton.style.background = 'rgba(255, 255, 255, 0.1)';
            }, 2000);
        });
    });

    const codeWindow = block.closest('.code-window');
    if (codeWindow) {
        codeWindow.style.position = 'relative';
        codeWindow.appendChild(copyButton);
    }
});


// ================================
// ANALYTICS TRACKING (Placeholder)
// ================================

const trackEvent = (category, action, label) => {
    // Replace with your analytics solution
    // Example: Google Analytics, Plausible, etc.
    console.log('Track Event:', { category, action, label });

    // Example for Google Analytics:
    // if (typeof gtag !== 'undefined') {
    //     gtag('event', action, {
    //         'event_category': category,
    //         'event_label': label
    //     });
    // }
};

// Track CTA clicks
const ctaLinks = document.querySelectorAll('a[href="/app"], a[href*="github"]');
ctaLinks.forEach(link => {
    link.addEventListener('click', () => {
        const isGithub = link.href.includes('github');
        trackEvent('CTA', 'click', isGithub ? 'GitHub' : 'Try App');
    });
});

// Track scroll depth
let scrollDepth = 0;
const trackScrollDepth = () => {
    const windowHeight = document.documentElement.scrollHeight - document.documentElement.clientHeight;
    const scrolled = Math.floor((window.pageYOffset / windowHeight) * 100);

    if (scrolled > scrollDepth && scrolled % 25 === 0) {
        scrollDepth = scrolled;
        trackEvent('Engagement', 'scroll', `${scrolled}%`);
    }
};

window.addEventListener('scroll', trackScrollDepth);


// ================================
// LOG WELCOME MESSAGE
// ================================

console.log('%c🎨 Simple Kanban', 'font-size: 24px; font-weight: bold; color: #6c5ce7;');
console.log('%cProject management made simple.', 'font-size: 14px; color: #636e72;');
console.log('%cLike what you see? Check out our code: https://github.com/your-repo', 'font-size: 12px; color: #b2bec3;');
console.log('%c💜 Built with love by developers who were tired of complicated tools.', 'font-size: 12px; color: #6c5ce7;');


// ================================
// INITIALIZE ON LOAD
// ================================

document.addEventListener('DOMContentLoaded', () => {
    console.log('Landing page loaded successfully!');

    // Add any initialization code here

    // Example: Show a subtle loading animation has completed
    document.body.style.opacity = '0';
    setTimeout(() => {
        document.body.style.transition = 'opacity 0.5s ease';
        document.body.style.opacity = '1';
    }, 100);
});
