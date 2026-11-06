const { geminiService } = require('../ai/geminiService');
const { db } = require('../config/db');
const { lifeEventEngine } = require('../core/lifeEventEngine');
const hdeService = require('../services/hdeService');

class HDEController {

    constructor() {
        this.getStats = this.getStats.bind(this);
        this.generateDailyTasks = this.generateDailyTasks.bind(this);
        this.completeDailyTask = this.completeDailyTask.bind(this);
        this.logActivity = this.logActivity.bind(this);
        this.submitSurvey = this.submitSurvey.bind(this);
        this._getFallbackDimensionCurriculum = this._getFallbackDimensionCurriculum.bind(this);
        this._parseJson = this._parseJson.bind(this);
    }

    _parseJson(value, fallback) {
        if (value == null) return fallback;
        if (typeof value !== 'string') return value;
        try {
            return JSON.parse(value);
        } catch (_) {
            return fallback;
        }
    }

    async getStats(req, res) {
        try {
            const { userId } = req.params;
            if (!userId) {
                return res.status(400).json({ success: false, message: 'User ID is required.' });
            }

            const stats = await hdeService.getStats(userId);
            res.json({ success: true, stats });
        } catch (error) {
            console.error('[HDEController] Error fetching stats:', error);
            res.status(500).json({ success: false, error: error.message });
        }
    }

    async generateDailyTasks(req, res) {
        try {
            const { userId, dimension } = req.body;
            const normalizedDimension = hdeService.normalizeDimension(dimension);
            if (!userId || !hdeService.isTrackedDimension(normalizedDimension)) {
                return res.status(400).json({ success: false, message: 'A valid user and HDE dimension are required.' });
            }
            const todayStr = new Date().toISOString().split('T')[0];

            const [rows] = await db.query(
                'SELECT * FROM daily_tasks WHERE user_id = ? AND dimension = ? AND task_date = ? LIMIT 1',
                [userId, normalizedDimension, todayStr]
            );

            if (rows.length > 0) {
                const data = rows[0];
                const parsedTasks = this._parseJson(data.tasks_json, []);
                const tasks = Array.isArray(parsedTasks) ? parsedTasks : [];
                const allCompleted = tasks.length > 0 && tasks.every(t => Boolean(t.completed));
                return res.json({
                    success: true,
                    isLocked: allCompleted,
                    surveySubmitted: Number(data.survey_submitted) === 1,
                    message: allCompleted ? "Training complete for today. See you tomorrow!" : "",
                    data: {
                        tasks: tasks,
                        flashcards: this._parseJson(data.flashcards_json, []),
                        surveyQuestions: this._parseJson(data.survey_questions_json, [])
                    }
                });
            }

            const [pastRows] = await db.query(
                'SELECT tasks_json FROM daily_tasks WHERE user_id = ? AND dimension = ? ORDER BY task_date DESC LIMIT 7',
                [userId, normalizedDimension]
            );

            let pastTasks = [];
            pastRows.forEach(row => {
                const tasks = this._parseJson(row.tasks_json, []);
                if (Array.isArray(tasks)) {
                    pastTasks.push(...tasks.map(t => t.title));
                }
            });

            const prompt = `
You are the AI behind the LifeVerse Evolution Matrix.
The user is focusing on the '${normalizedDimension}' dimension.
Past 7 days tasks (DO NOT REPEAT THESE): ${JSON.stringify(pastTasks)}

Generate EXACTLY 5 new tasks for today.
Also generate 3 short, motivational flashcards related to this dimension.
FINALLY, generate EXACTLY 5 unique, personalized questions to ask the user after they complete the tasks.
- 1 question should be about today's tasks/performance.
- 2 questions should be deep personal questions (e.g., family, long-term goals, background).
- 1 question should be about their mental/physical health.
- 1 question should be a hypothetical scenario or situation-based question.

Return strictly in JSON format:
{
  "tasks": [
    { "title": "...", "description": "...", "expReward": 25, "completed": false }
  ],
  "flashcards": [
    { "frontText": "...", "backText": "..." }
  ],
  "surveyQuestions": [
    "Question 1?",
    "Question 2?"
  ]
}
            `;

            let parsedData;
            try {
                const result = await geminiService.model.generateContent(prompt);
                const rawResponse = result.response.text();
                parsedData = JSON.parse(rawResponse.replace(/```json\n?|```/g, '').trim());
            } catch (e) {
                console.warn('[HDEController] Gemini task generation failed or unparseable. Falling back to deterministic curriculum.', e.message);
                parsedData = this._getFallbackDimensionCurriculum(normalizedDimension);
            }

            // Never persist arbitrary model-generated reward values or malformed task lists.
            if (!parsedData || !Array.isArray(parsedData.tasks) || parsedData.tasks.length !== 5) {
                parsedData = this._getFallbackDimensionCurriculum(normalizedDimension);
            }
            parsedData.tasks = parsedData.tasks.map((task, index) => ({
                title: String(task?.title || `Daily task ${index + 1}`).slice(0, 160),
                description: String(task?.description || '').slice(0, 1000),
                expReward: Math.max(10, Math.min(50, Math.floor(Number(task?.expReward) || 25))),
                completed: false
            }));
            if (!Array.isArray(parsedData.flashcards)) parsedData.flashcards = [];
            if (!Array.isArray(parsedData.surveyQuestions) || parsedData.surveyQuestions.length !== 5) {
                parsedData.surveyQuestions = this._getFallbackDimensionCurriculum(normalizedDimension).surveyQuestions;
            }
            parsedData.flashcards = parsedData.flashcards.slice(0, 10)
                .filter(card => card && typeof card === 'object')
                .map(card => ({
                    frontText: String(card.frontText || '').slice(0, 250),
                    backText: String(card.backText || '').slice(0, 1000)
                }));
            parsedData.surveyQuestions = parsedData.surveyQuestions.map(q => String(q).slice(0, 500));

            const taskId = require('crypto').randomUUID();
            try {
                await db.query(
                    'INSERT INTO daily_tasks (id, user_id, dimension, task_date, tasks_json, flashcards_json, survey_questions_json) VALUES (?, ?, ?, ?, ?, ?, ?)',
                    [taskId, userId, normalizedDimension, todayStr, JSON.stringify(parsedData.tasks), JSON.stringify(parsedData.flashcards), JSON.stringify(parsedData.surveyQuestions)]
                );
            } catch (insertError) {
                // Two first-time requests may both generate a curriculum. The
                // unique daily-task key chooses one; the other returns that row.
                if (insertError.code !== 'ER_DUP_ENTRY') throw insertError;
                const [winnerRows] = await db.query(
                    'SELECT tasks_json, flashcards_json, survey_questions_json, survey_submitted FROM daily_tasks WHERE user_id = ? AND dimension = ? AND task_date = ? LIMIT 1',
                    [userId, normalizedDimension, todayStr]
                );
                if (winnerRows.length === 0) throw insertError;
                const winner = winnerRows[0];
                const winnerTasksValue = this._parseJson(winner.tasks_json, []);
                const winnerTasks = Array.isArray(winnerTasksValue) ? winnerTasksValue : [];
                const allCompleted = winnerTasks.length > 0 && winnerTasks.every(task => Boolean(task.completed));
                return res.json({
                    success: true,
                    isLocked: allCompleted,
                    surveySubmitted: Number(winner.survey_submitted) === 1,
                    message: allCompleted ? 'Training complete for today. See you tomorrow!' : '',
                    data: {
                        tasks: winnerTasks,
                        flashcards: this._parseJson(winner.flashcards_json, []),
                        surveyQuestions: this._parseJson(winner.survey_questions_json, [])
                    }
                });
            }

            res.json({
                success: true,
                isLocked: false,
                surveySubmitted: false,
                data: {
                    tasks: parsedData.tasks,
                    flashcards: parsedData.flashcards,
                    surveyQuestions: parsedData.surveyQuestions
                }
            });
        } catch (error) {
            console.error('[HDEController] Error generating tasks:', error);
            res.status(500).json({ success: false, error: error.message });
        }
    }

    _getFallbackDimensionCurriculum(dimension) {
        const fallbacks = {
            physical: {
                tasks: [
                    { title: "Hydration Protocol", description: "Drink 500ml of clean water upon rising.", expReward: 20, completed: false },
                    { title: "Kinetic Movement", description: "Complete a 15-minute brisk walk or light stretching.", expReward: 25, completed: false },
                    { title: "Posture Check", description: "Perform 3 posture resets during work hours.", expReward: 20, completed: false },
                    { title: "Nutrient Discipline", description: "Include at least one portion of raw greens with a meal.", expReward: 25, completed: false },
                    { title: "Digital Sunset", description: "Power down screens 30 minutes before sleep.", expReward: 30, completed: false }
                ],
                flashcards: [
                    { frontText: "Hydration & Cognition", backText: "A 2% drop in body water noticeably reduces mental focus." },
                    { frontText: "Circadian Rhythm", backText: "Morning sunlight within 30 minutes of waking anchors cortisol." },
                    { frontText: "Movement Recovery", backText: "Low-intensity walking accelerates metabolic waste clearance." }
                ],
                surveyQuestions: [
                    "How rested did you feel when you woke up this morning?",
                    "What physical habit felt easiest to maintain today?",
                    "Did you experience any physical tension or fatigue?",
                    "What is one physical challenge you wish to conquer this month?",
                    "If you had to run 5 kilometers right now, how confident would you feel?"
                ]
            },
            cognitive: {
                tasks: [
                    { title: "Deep Work Block", description: "Dedicate 25 minutes of uninterrupted focus to one complex task.", expReward: 25, completed: false },
                    { title: "Active Recall", description: "Write down 3 key concepts learned recently from memory.", expReward: 25, completed: false },
                    { title: "Curiosity Inquiry", description: "Read or listen to 10 minutes of educational content outside your field.", expReward: 20, completed: false },
                    { title: "Cognitive Declutter", description: "Offload 5 lingering thoughts into a brain-dump note.", expReward: 20, completed: false },
                    { title: "Analytical Review", description: "Examine one decision you made recently and identify alternative paths.", expReward: 30, completed: false }
                ],
                flashcards: [
                    { frontText: "Feynman Technique", backText: "If you cannot explain a concept simply, you do not truly understand it." },
                    { frontText: "Cognitive Load", backText: "Context switching incurs an attention residue penalty of up to 20 minutes." },
                    { frontText: "Spaced Repetition", backText: "Retrieval strength multiplies when tested right as decay begins." }
                ],
                surveyQuestions: [
                    "How focused was your primary work session today?",
                    "What was the most intellectually stimulating insight you encountered?",
                    "Where did you feel mental friction or procrastination?",
                    "What cognitive skill are you most keen to cultivate?",
                    "If given 48 hours with no obligations, what subject would you study?"
                ]
            },
            psychosocial: {
                tasks: [
                    { title: "Authentic Outreach", description: "Send a genuine check-in message to a close friend or family member.", expReward: 25, completed: false },
                    { title: "Active Listening", description: "Listen to someone speak for 5 minutes without planning your reply.", expReward: 25, completed: false },
                    { title: "Emotional Check-in", description: "Name your dominant emotion today and note what triggered it.", expReward: 20, completed: false },
                    { title: "Shared Gratitude", description: "Express specific appreciation to someone who helped you.", expReward: 25, completed: false },
                    { title: "Boundary Practice", description: "Identify one healthy boundary to uphold in your relationships.", expReward: 25, completed: false }
                ],
                flashcards: [
                    { frontText: "Empathetic Attunement", backText: "Validation of feelings precedes constructive resolution." },
                    { frontText: "Social Mirroring", backText: "The five people you spend most time with shape your emotional baseline." },
                    { frontText: "Vulnerability Strength", backText: "Clear vulnerability fosters deeper trust than projected perfection." }
                ],
                surveyQuestions: [
                    "How connected did you feel to those around you today?",
                    "Who in your life brings you the greatest sense of calm?",
                    "What difficult conversation have you been delaying?",
                    "How do you typically react when someone misunderstands your intent?",
                    "If a friend came to you with a life crisis, what would your first reaction be?"
                ]
            },
            moral: {
                tasks: [
                    { title: "Principle Audit", description: "Reflect on one decision made this week and whether it aligned with your core values.", expReward: 25, completed: false },
                    { title: "Anonymous Kindness", description: "Perform one helpful act for another person without seeking credit.", expReward: 30, completed: false },
                    { title: "Truth Alignment", description: "Speak with rigorous honesty in every interaction today.", expReward: 25, completed: false },
                    { title: "Accountability Check", description: "Acknowledge one minor mistake directly and take ownership.", expReward: 25, completed: false },
                    { title: "Ethical Inquiry", description: "Reflect on how your work impacts your community or the world.", expReward: 25, completed: false }
                ],
                flashcards: [
                    { frontText: "Integrity Defined", backText: "Integrity is doing the right thing even when no one is watching." },
                    { frontText: "Stoic Dichotomy", backText: "Focus strictly on what is in your control: your choices and character." },
                    { frontText: "The Golden Rule", backText: "Treat others as you would wish to be treated under identical circumstances." }
                ],
                surveyQuestions: [
                    "Did you encounter any ethical dilemma or conflict today?",
                    "What core principle guides you when decisions are ambiguous?",
                    "What is something you used to believe that you have now re-evaluated?",
                    "Who is an individual whose moral character you deeply admire, and why?",
                    "If your choices today were published openly, would you feel proud?"
                ]
            }
        };

        const key = String(dimension).toLowerCase();
        return fallbacks[key] || fallbacks.cognitive;
    }

    async completeDailyTask(req, res) {
        let connection;
        let transactionStarted = false;
        try {
            const { userId, dimension, taskTitle } = req.body;
            const normalizedDimension = hdeService.normalizeDimension(dimension);
            if (!userId || !taskTitle || !hdeService.isTrackedDimension(normalizedDimension)) {
                return res.status(400).json({ success: false, message: 'A valid user, task, and HDE dimension are required.' });
            }
            const todayStr = new Date().toISOString().split('T')[0];

            connection = await db.getConnection();
            await connection.beginTransaction();
            transactionStarted = true;

            const [rows] = await connection.query(
                'SELECT id, tasks_json FROM daily_tasks WHERE user_id = ? AND dimension = ? AND task_date = ? LIMIT 1 FOR UPDATE',
                [userId, normalizedDimension, todayStr]
            );

            if (rows.length === 0) {
                await connection.rollback();
                transactionStarted = false;
                return res.status(404).json({ success: false, message: 'Daily tasks not found.' });
            }

            const row = rows[0];
            let tasks = this._parseJson(row.tasks_json, []);
            let completedTask = null;
            let taskFound = false;
            let alreadyCompleted = false;

            for (const t of tasks) {
                if (t.title === taskTitle) {
                    taskFound = true;
                    if (t.completed) {
                        alreadyCompleted = true;
                    } else {
                        t.completed = true;
                    }
                    completedTask = t;
                    break;
                }
            }

            if (!taskFound) {
                await connection.rollback();
                transactionStarted = false;
                return res.status(404).json({ success: false, message: 'Task not found for today.' });
            }

            const allCompleted = tasks.every(t => Boolean(t.completed));

            if (alreadyCompleted) {
                const currentStats = await hdeService.getStats(userId, connection);
                await connection.commit();
                transactionStarted = false;
                return res.json({
                    success: true,
                    alreadyCompleted: true,
                    allCompleted,
                    xpGained: 0,
                    message: 'Task already completed today.',
                    hde: currentStats
                });
            }

            await connection.query(
                'UPDATE daily_tasks SET tasks_json = ? WHERE id = ?',
                [JSON.stringify(tasks), row.id]
            );

            // Route through the central nervous system
            const reward = Math.max(10, Math.min(50, Math.floor(Number(completedTask?.expReward) || 25)));
            const eventResult = await lifeEventEngine.processEvent({
                userId,
                type: 'TASK_COMPLETED',
                details: {
                    taskTitle,
                    dimension: normalizedDimension
                }
            }, { executor: connection, taskXpReward: reward });

            await connection.commit();
            transactionStarted = false;

            res.json({
                success: true,
                alreadyCompleted: false,
                allCompleted,
                xpGained: eventResult.xpGained,
                hde: eventResult.results?.hde || null
            });
        } catch (error) {
            if (transactionStarted) await connection.rollback().catch(() => {});
            console.error('[HDEController] Error completing task:', error);
            res.status(500).json({ success: false, error: error.message });
        } finally {
            connection?.release();
        }
    }

    async logActivity(req, res) {
        try {
            const { userId, dimension, metadata, details } = req.body;

            if (!userId) {
                return res.status(400).json({ success: false, message: 'User ID is required.' });
            }

            const normalizedDimension = dimension == null ? null : hdeService.normalizeDimension(dimension);
            if (normalizedDimension && !hdeService.isTrackedDimension(normalizedDimension)) {
                return res.status(400).json({ success: false, message: 'Invalid HDE dimension.' });
            }
            const safeMetadata = metadata && typeof metadata === 'object' && !Array.isArray(metadata) ? metadata : {};
            const safeDetails = details && typeof details === 'object' && !Array.isArray(details) ? details : {};
            const eventDetails = { metadata: safeMetadata, details: safeDetails };
            if (JSON.stringify(eventDetails).length > 8000) {
                return res.status(400).json({ success: false, message: 'Activity metadata is too large.' });
            }

            const eventType = 'HDE_ACTIVITY_LOGGED';
            const eventResult = await lifeEventEngine.processEvent({
                userId,
                type: eventType,
                details: {
                    ...eventDetails,
                    dimension: normalizedDimension,
                }
            });

            res.json({
                success: true,
                message: 'Activity logged successfully.',
                eventType,
                xpGained: eventResult.xpGained,
                results: eventResult.results
            });
        } catch (error) {
            console.error('[HDEController] Error logging activity:', error);
            res.status(500).json({ success: false, error: error.message });
        }
    }

    async submitSurvey(req, res) {
        let connection;
        let transactionStarted = false;
        try {
            const { userId, dimension, surveyData } = req.body;
            const normalizedDimension = hdeService.normalizeDimension(dimension);
            if (!userId || !hdeService.isTrackedDimension(normalizedDimension) ||
                !Array.isArray(surveyData) || surveyData.length === 0 || surveyData.length > 20) {
                return res.status(400).json({ success: false, message: 'Valid survey answers and HDE dimension are required.' });
            }

            const todayStr = new Date().toISOString().split('T')[0];
            connection = await db.getConnection();
            await connection.beginTransaction();
            transactionStarted = true;

            const [dailyRows] = await connection.query(
                'SELECT id, tasks_json, survey_questions_json, survey_submitted FROM daily_tasks WHERE user_id = ? AND dimension = ? AND task_date = ? LIMIT 1 FOR UPDATE',
                [userId, normalizedDimension, todayStr]
            );
            if (!dailyRows.length) {
                await connection.rollback();
                transactionStarted = false;
                return res.status(409).json({ success: false, message: 'Complete today’s tasks before submitting the review.' });
            }
            const tasks = this._parseJson(dailyRows[0].tasks_json, []);
            if (!Array.isArray(tasks) || tasks.length === 0 || !tasks.every(task => task.completed)) {
                await connection.rollback();
                transactionStarted = false;
                return res.status(409).json({ success: false, message: 'Complete today’s tasks before submitting the review.' });
            }
            if (Number(dailyRows[0].survey_submitted) === 1) {
                await connection.commit();
                transactionStarted = false;
                return res.json({ success: true, alreadySubmitted: true, xpGained: 0, message: 'Review already submitted.' });
            }

            const questions = this._parseJson(dailyRows[0].survey_questions_json, []);
            const validAnswers = Array.isArray(questions) && surveyData.length === questions.length &&
                surveyData.every((answer, index) =>
                    answer && typeof answer === 'object' &&
                    answer.question === questions[index] &&
                    typeof answer.answer === 'string' &&
                    answer.answer.trim().length > 0 &&
                    answer.answer.length <= 4000
                );
            if (!validAnswers) {
                await connection.rollback();
                transactionStarted = false;
                return res.status(400).json({ success: false, message: 'Answer every review question before submitting.' });
            }

            const normalizedAnswers = surveyData.map(answer => ({
                question: answer.question,
                answer: answer.answer.trim()
            }));
            const serializedAnswers = JSON.stringify(normalizedAnswers);
            if (serializedAnswers.length > 20000) {
                await connection.rollback();
                transactionStarted = false;
                return res.status(400).json({ success: false, message: 'Survey answers are too long.' });
            }

            await connection.query(
                'INSERT INTO survey_answers (user_id, dimension, qna_json) VALUES (?, ?, ?)',
                [userId, normalizedDimension, serializedAnswers]
            );

            const eventResult = await lifeEventEngine.processEvent({
                userId,
                type: 'SURVEY_SUBMITTED',
                // Answers are stored in survey_answers, not copied into the
                // general analytics/event metadata table.
                details: { dimension: normalizedDimension, answerCount: normalizedAnswers.length }
            }, { executor: connection });

            await connection.query('UPDATE daily_tasks SET survey_submitted = 1 WHERE id = ?', [dailyRows[0].id]);
            await connection.commit();
            transactionStarted = false;

            res.json({
                success: true,
                message: 'Survey data saved successfully.',
                xpGained: eventResult.xpGained
            });
        } catch (error) {
            if (transactionStarted) await connection.rollback().catch(() => {});
            console.error('[HDEController] Error submitting survey:', error);
            res.status(500).json({ success: false, error: error.message });
        } finally {
            connection?.release();
        }
    }
}

module.exports = new HDEController();
