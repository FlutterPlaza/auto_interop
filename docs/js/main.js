(function() {
  // Theme toggle
  const themes = ['auto', 'light', 'dark'];
  const themeLabels = { auto: 'Auto', light: 'Light', dark: 'Dark' };
  const themeIcons = { auto: '\u2600', light: '\u2600', dark: '\u263E' };

  function getTheme() {
    return localStorage.getItem('ai-docs-theme') || 'auto';
  }

  function setTheme(theme) {
    document.documentElement.setAttribute('data-theme', theme);
    localStorage.setItem('ai-docs-theme', theme);
    document.querySelectorAll('.theme-icon').forEach(el => el.textContent = themeIcons[theme]);
    document.querySelectorAll('.theme-label').forEach(el => el.textContent = themeLabels[theme]);

    // Toggle Prism dark theme
    const isDark = theme === 'dark' || (theme === 'auto' && window.matchMedia('(prefers-color-scheme: dark)').matches);
    const darkSheet = document.getElementById('prism-dark');
    if (darkSheet) darkSheet.disabled = !isDark;
  }

  window.cycleTheme = function() {
    const current = getTheme();
    const next = themes[(themes.indexOf(current) + 1) % themes.length];
    setTheme(next);
  };

  // Init theme
  setTheme(getTheme());

  // Listen for system theme changes
  window.matchMedia('(prefers-color-scheme: dark)').addEventListener('change', function() {
    if (getTheme() === 'auto') setTheme('auto');
  });

  // Mobile sidebar
  window.toggleSidebar = function() {
    document.getElementById('sidebar').classList.toggle('open');
    document.getElementById('sidebar-overlay').classList.toggle('open');
  };
  window.closeSidebar = function() {
    document.getElementById('sidebar').classList.remove('open');
    document.getElementById('sidebar-overlay').classList.remove('open');
  };
  document.addEventListener('keydown', function(e) {
    if (e.key === 'Escape') closeSidebar();
  });

  // Close sidebar on link click (mobile)
  document.querySelectorAll('.sidebar-nav a').forEach(function(link) {
    link.addEventListener('click', function() {
      if (window.innerWidth <= 768) closeSidebar();
    });
  });

  // Active section tracking
  var sidebarLinks = document.querySelectorAll('.sidebar-nav a');
  var sections = document.querySelectorAll('main section[id]');

  var observer = new IntersectionObserver(function(entries) {
    entries.forEach(function(entry) {
      if (entry.isIntersecting) {
        sidebarLinks.forEach(function(link) { link.classList.remove('active'); });
        var activeLink = document.querySelector('.sidebar-nav a[href="#' + entry.target.id + '"]');
        if (activeLink) {
          activeLink.classList.add('active');
          // Scroll active link into view in sidebar
          activeLink.scrollIntoView({ block: 'nearest', behavior: 'smooth' });
        }
      }
    });
  }, { rootMargin: '-80px 0px -70% 0px', threshold: 0 });

  sections.forEach(function(section) { observer.observe(section); });

  // Copy to clipboard
  document.querySelectorAll('pre').forEach(function(pre) {
    var btn = document.createElement('button');
    btn.className = 'copy-btn';
    btn.textContent = 'Copy';
    btn.addEventListener('click', function() {
      var code = pre.querySelector('code');
      if (!code) return;
      navigator.clipboard.writeText(code.textContent).then(function() {
        btn.textContent = '\u2713 Copied';
        btn.classList.add('copied');
        setTimeout(function() {
          btn.textContent = 'Copy';
          btn.classList.remove('copied');
        }, 2000);
      });
    });
    pre.appendChild(btn);
  });

  // Search
  var searchInput = document.getElementById('search');
  var debounceTimer;

  searchInput.addEventListener('input', function() {
    clearTimeout(debounceTimer);
    debounceTimer = setTimeout(function() {
      var query = searchInput.value.toLowerCase().trim();
      sections.forEach(function(section) {
        if (!query) {
          section.classList.remove('search-hidden');
        } else {
          var text = section.textContent.toLowerCase();
          section.classList.toggle('search-hidden', !text.includes(query));
        }
      });
      sidebarLinks.forEach(function(link) {
        var href = link.getAttribute('href');
        var sectionId = href ? href.substring(1) : '';
        var section = document.getElementById(sectionId);
        if (!query) {
          link.classList.remove('search-hidden');
        } else if (section) {
          link.classList.toggle('search-hidden', section.classList.contains('search-hidden'));
        }
      });
    }, 200);
  });
})();
