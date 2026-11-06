const { GoogleGenAI } = require('@google/genai');
const dotenv = require('dotenv');

dotenv.config();

class GeminiService {
    constructor() {
        // Initialize the new SDK
        this.client = new GoogleGenAI({ apiKey: process.env.GEMINI_API_KEY });
        
        // Mock the old generative-ai SDK interface so we don't have to rewrite 5 controllers
        this.model = {
            generateContent: async (prompt) => {
                const response = await this.client.models.generateContent({
                    model: 'gemini-2.5-flash',
                    contents: prompt
                });
                
                return {
                    response: {
                        text: () => response.text
                    }
                };
            }
        };
    }

    async analyzeLifeEvent(eventData, userContext) {
        try {
            const prompt = `
            Analyze this life event: ${JSON.stringify(eventData)}.
            User Context: ${JSON.stringify(userContext)}.
            What should be updated in their Digital Twin profile and Future Simulation?
            `;
            const result = await this.model.generateContent(prompt);
            return result.response.text();
        } catch (error) {
            console.error('[GeminiService] Error analyzing life event:', error);
            throw error;
        }
    }
}

const geminiService = new GeminiService();
module.exports = { geminiService };
